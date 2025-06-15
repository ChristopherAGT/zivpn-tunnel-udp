#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║                    🧩 ZIVPN - PANEL DE USUARIOS UDP - v1.0                 ║
# ╚════════════════════════════════════════════════════════════════════════════╝

# 📁 Archivos
CONFIG_FILE="/etc/zivpn/config.json"
USER_DB="/etc/zivpn/users.db"
CONF_FILE="/etc/zivpn.conf"
BACKUP_FILE="/etc/zivpn/config.json.bak"

# 🎨 Colores
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

# 🧽 Limpiar pantalla
clear

# 🛠️ Dependencias
command -v jq >/dev/null 2>&1 || { echo -e "${RED}❌ jq no está instalado. Usa: apt install jq -y${RESET}"; exit 1; }

# 🧠 Crear archivos si no existen
mkdir -p /etc/zivpn
[ ! -f "$CONFIG_FILE" ] && echo '{"listen":":5667","cert":"/etc/zivpn/zivpn.crt","key":"/etc/zivpn/zivpn.key","obfs":"zivpn","auth":{"mode":"passwords","config":["zivpn"]}}' > "$CONFIG_FILE"
[ ! -f "$USER_DB" ] && touch "$USER_DB"
[ ! -f "$CONF_FILE" ] && echo 'AUTOCLEAN=OFF' > "$CONF_FILE"

# 🔁 Cargar configuración
source "$CONF_FILE"

# 📦 Funciones principales

add_user() {
  # Solicitar contraseña y validar que no esté vacía ni exista ya
  while true; do
    read -p "🔐 Ingrese la nueva contraseña: " pass
    if [[ -z "$pass" ]]; then
      echo -e "${RED}❌ La contraseña no puede estar vacía.${RESET}"
      continue
    fi
    if jq -e --arg pw "$pass" '.auth.config | index($pw)' "$CONFIG_FILE" > /dev/null; then
      echo -e "${RED}❌ La contraseña ya existe.${RESET}"
      continue
    fi
    break
  done

  # Solicitar días de expiración y validar que sea número positivo
  while true; do
    read -p "📅 Días de expiración: " days
    if [[ ! "$days" =~ ^[0-9]+$ ]] || [[ "$days" -le 0 ]]; then
      echo -e "${RED}❌ Ingrese un número válido y positivo.${RESET}"
    else
      break
    fi
  done

  exp_date=$(date -d "+$days days" +%Y-%m-%d)

  # Crear backup antes de modificar
  cp "$CONFIG_FILE" "$BACKUP_FILE"

  # Añadir usuario a la configuración JSON
  jq --arg pw "$pass" '.auth.config += [$pw]' "$CONFIG_FILE" > temp && mv temp "$CONFIG_FILE"

  # Añadir usuario a la base de datos con formato uniforme
  echo "$pass | $exp_date" >> "$USER_DB"

  echo -e "${GREEN}✅ Usuario añadido con expiración: $exp_date${RESET}"

  # Reiniciar servicio para aplicar cambios
  systemctl restart zivpn.service
}

remove_user() {
  list_users
  read -p "🔢 Ingrese el número del usuario a eliminar: " id

  sel_pass=$(sed -n "${id}p" "$USER_DB" | cut -d'|' -f1 | xargs)

  if [[ -z "$sel_pass" ]]; then
    echo -e "${RED}❌ ID inválido.${RESET}"
    return
  fi

  cp "$CONFIG_FILE" "$BACKUP_FILE"

  jq --arg pw "$sel_pass" '.auth.config -= [$pw]' "$CONFIG_FILE" > temp && mv temp "$CONFIG_FILE"

  sed -i "/^$sel_pass[[:space:]]*|/d" "$USER_DB"

  echo -e "${GREEN}🗑️ Usuario eliminado exitosamente.${RESET}"

  systemctl restart zivpn.service
}

renew_user() {
  list_users

  # Validar ID válido
  while true; do
    read -p "🔢 ID del usuario a renovar: " id
    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
      echo -e "${RED}❌ Por favor ingrese un número válido.${RESET}"
    else
      sel_pass=$(sed -n "${id}p" "$USER_DB" | cut -d'|' -f1 | xargs)
      if [[ -z "$sel_pass" ]]; then
        echo -e "${RED}❌ ID inválido o no existe.${RESET}"
      else
        break
      fi
    fi
  done

  # Validar días adicionales
  while true; do
    read -p "📅 Días adicionales: " days
    if [[ ! "$days" =~ ^[0-9]+$ ]] || [[ "$days" -le 0 ]]; then
      echo -e "${RED}❌ Ingrese un número positivo válido.${RESET}"
    else
      break
    fi
  done

  old_exp=$(sed -n "/^$sel_pass[[:space:]]*|/p" "$USER_DB" | cut -d'|' -f2 | xargs)
  if [[ -z "$old_exp" ]]; then
    echo -e "${RED}❌ No se encontró la fecha de expiración para este usuario.${RESET}"
    return
  fi

  new_exp=$(date -d "$old_exp +$days days" +%Y-%m-%d)

  # Actualizar fecha en USER_DB
  sed -i "s/^$sel_pass[[:space:]]*|.*/$sel_pass | $new_exp/" "$USER_DB"

  echo -e "${GREEN}🔁 Usuario renovado hasta: $new_exp${RESET}"

  systemctl restart zivpn.service
}

list_users() {
  echo -e "\n${CYAN}📋 LISTA DE USUARIOS REGISTRADOS${RESET}"
  echo -e "${CYAN}╔════╦══════════════════════╦══════════════════╦══════════════════╗${RESET}"
  echo -e "${CYAN}║ ID ║     CONTRASEÑA       ║     EXPIRA       ║     ESTADO       ║${RESET}"
  echo -e "${CYAN}╠════╬══════════════════════╬══════════════════╬══════════════════╣${RESET}"

  i=1
  today=$(date +%Y-%m-%d)
  while IFS='|' read -r pass exp; do
    pass=$(echo "$pass" | xargs)
    exp=$(echo "$exp" | xargs)

    if [[ "$exp" < "$today" ]]; then
      status="🔴 VENCIDO"
    else
      status="🟢 ACTIVO"
    fi

    printf "${CYAN}║ %2s ║ ${YELLOW}%-20s${CYAN} ║ ${YELLOW}%-16s${CYAN} ║ ${YELLOW}%-14s${CYAN}     ║${RESET}\n" "$i" "$pass" "$exp" "$status"
    ((i++))
  done < "$USER_DB"

  echo -e "${CYAN}╚════╩══════════════════════╩══════════════════╩══════════════════╝${RESET}\n"
  # Solo mostrar pausa si se llama con argumento true
  [[ "$1" == "true" ]] && read -p "🔙 Presione Enter para volver al menú..."
}

clean_expired_users() {
  local today=$(date +%Y-%m-%d)
  local updated=0
  local expired=()

  cp "$CONFIG_FILE" "$BACKUP_FILE"

  while IFS='|' read -r pass exp; do
    pass=$(echo "$pass" | xargs)
    exp=$(echo "$exp" | xargs)
    if [[ "$exp" < "$today" ]]; then
      expired+=("$pass")
    fi
  done < "$USER_DB"

  if [[ ${#expired[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ No hay usuarios expirados para eliminar.${RESET}"
    return
  fi

  # Actualizar config.json eliminando todos los usuarios expirados de una vez
  local jq_filter='.'
  for pw in "${expired[@]}"; do
    jq_filter+=" | del(.auth.config[] | select(. == \"$pw\"))"
  done

  if ! jq "$jq_filter" "$CONFIG_FILE" > temp && mv temp "$CONFIG_FILE"; then
    echo -e "${RED}❌ Error al actualizar $CONFIG_FILE con jq.${RESET}"
    return 1
  fi

  # Eliminar usuarios expirados de USER_DB de forma segura
  local temp_db=$(mktemp)
  grep -v -F -f <(printf '%s\n' "${expired[@]}") "$USER_DB" > "$temp_db" && mv "$temp_db" "$USER_DB"

  for u in "${expired[@]}"; do
    echo -e "${YELLOW}🧹 Usuario expirado eliminado: $u${RESET}"
  done

  systemctl restart zivpn.service
  echo -e "${GREEN}✅ Limpieza finalizada y servicio reiniciado.${RESET}"
}

toggle_autoclean() {
  if [[ "$AUTOCLEAN" == "ON" ]]; then
    echo "AUTOCLEAN=OFF" > "$CONF_FILE"
    AUTOCLEAN=OFF
  else
    echo "AUTOCLEAN=ON" > "$CONF_FILE"
    AUTOCLEAN=ON
  fi
}

# ▶️ Servicio
start_service()    { systemctl start zivpn.service && echo -e "${GREEN}▶️ Servicio iniciado.${RESET}"; }
stop_service()     { systemctl stop zivpn.service && echo -e "${RED}⏹️ Servicio detenido.${RESET}"; }
restart_service()  { systemctl restart zivpn.service && echo -e "${YELLOW}🔁 Servicio reiniciado.${RESET}"; }

# 📺 Menú principal
while true; do
  clear  # ✅ Limpia la pantalla en cada iteración del menú

[[ "$AUTOCLEAN" == "ON" ]] && clean_expired_users > /dev/null

# Obtener datos reales
IP_MACHINE=$(hostname -I | awk '{print $1}')
OS_MACHINE=$(grep -oP '^PRETTY_NAME="\K[^"]+' /etc/os-release)
ARCH_MACHINE=$(uname -m)
# Normalizar arquitectura para mostrar AMD o ARM
if [[ "$ARCH_MACHINE" =~ "arm" || "$ARCH_MACHINE" =~ "aarch" ]]; then
  ARCH_DISPLAY="ARM"
else
  ARCH_DISPLAY="AMD"
fi
PORT="5667"
PORT_RANGE="6000-19999"

echo -e "\n${CYAN}╔═════════════════════════════════════════════════════════════════╗"
echo -e "║                🧩 ZIVPN - PANEL DE USUARIOS UDP                 ║"
echo -e "╠═════════════════════════════════════════════════════════════════╣"
echo -e "║                         📊 INFORMACIÓN                          ║"
echo -e "╠═════════════════════════════════════════════════════════════════╣"
echo -e "${CYAN}║ 📶 IP:           ${GREEN}${IP_MACHINE}${CYAN}                                    ║"
echo -e "${CYAN}║ 🖥️ OS:           ${GREEN}${OS_MACHINE}${CYAN}                                    ║"
echo -e "${CYAN}║ 🧠 Arquitectura: ${GREEN}${ARCH_DISPLAY}${CYAN}                                  ║"
echo -e "${CYAN}║ 📍 Puerto:       ${GREEN}${PORT}${CYAN}                                          ║"
echo -e "${CYAN}║ 🔥 IPTABLES:     ${GREEN}${PORT_RANGE}${CYAN}                                    ║"
echo -e "╠═════════════════════════════════════════════════════════════════╣"
echo -e "║ [1] ➕  Crear nuevo usuario (con expiración)                    ║"
echo -e "║ [2] ❌  Remover usuario                                         ║"
echo -e "║ [3] 🗓  Renovar usuario                                         ║"
echo -e "║ [4] 📋  Información de los usuarios                             ║"
echo -e "║ [5] ▶️  Iniciar servicio                                        ║"
echo -e "║ [6] 🔁  Reiniciar servicio                                      ║"
echo -e "║ [7] ⏹️  Detener servicio                                        ║"
if [[ "$AUTOCLEAN" == "ON" ]]; then
  echo -e "║ [8] 🧹  Eliminar usuarios vencidos            [${GREEN}ON${CYAN}]              ║"
else
  echo -e "║ [8] 🧹  Eliminar usuarios vencidos            [${RED}OFF${CYAN}]             ║"
fi
echo -e "║ [9] 🚪  Salir                                                   ║"
echo -e "╚═════════════════════════════════════════════════════════════════╝${RESET}"

read -p "📌 Seleccione una opción: " opc
case $opc in
  1) add_user;;
  2) remove_user;;
  3) renew_user;;
  4) list_users true;;
  5) start_service;;
  6) restart_service;;
  7) stop_service;;
  8) toggle_autoclean;;
  9) exit;;
  *) echo -e "${RED}❌ Opción inválida.${RESET}";;
esac
done
