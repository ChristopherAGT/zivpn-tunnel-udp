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

#limpiar
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
  read -p "🔐 Ingrese la nueva contraseña: " pass
  if jq -e --arg pw "$pass" '.auth.config | index($pw)' "$CONFIG_FILE" > /dev/null; then
    echo -e "${RED}❌ La contraseña ya existe.${RESET}"
    return
  fi
  read -p "📅 Días de expiración: " days
  exp_date=$(date -d "+$days days" +%Y-%m-%d)
  cp "$CONFIG_FILE" "$BACKUP_FILE"
  jq --arg pw "$pass" '.auth.config += [$pw]' "$CONFIG_FILE" > temp && mv temp "$CONFIG_FILE"
  echo "$pass | $exp_date" >> "$USER_DB"
  echo -e "${GREEN}✅ Usuario añadido con expiración: $exp_date${RESET}"
  systemctl restart zivpn.service
}

remove_user() {
  list_users
  read -p "🔢 Ingrese el número del usuario a eliminar: " id
  sel_pass=$(awk -F' | ' "NR==$id{print \$1}" "$USER_DB")
  [ -z "$sel_pass" ] && echo -e "${RED}❌ ID inválido.${RESET}" && return
  cp "$CONFIG_FILE" "$BACKUP_FILE"
  jq --arg pw "$sel_pass" '.auth.config -= [$pw]' "$CONFIG_FILE" > temp && mv temp "$CONFIG_FILE"
  grep -v "^$sel_pass |" "$USER_DB" > temp && mv temp "$USER_DB"
  echo -e "${GREEN}🗑️ Usuario eliminado exitosamente.${RESET}"
  systemctl restart zivpn.service
}

renew_user() {
  list_users
  read -p "🔢 ID del usuario a renovar: " id
  sel_pass=$(awk -F' | ' "NR==$id{print \$1}" "$USER_DB")
  [ -z "$sel_pass" ] && echo -e "${RED}❌ ID inválido.${RESET}" && return
  read -p "📅 Días adicionales: " days
  old_exp=$(awk -F' | ' "\$1==\"$sel_pass\"{print \$3}" "$USER_DB")
  new_exp=$(date -d "$old_exp +$days days" +%Y-%m-%d)
  sed -i "s/^$sel_pass |.*/$sel_pass | $new_exp/" "$USER_DB"
  echo -e "${GREEN}🔁 Usuario renovado hasta: $new_exp${RESET}"
  systemctl restart zivpn.service
}

list_users() {
  echo -e "\n${CYAN}📋 LISTA DE USUARIOS REGISTRADOS${RESET}"
  echo -e "${CYAN}╔════╦════════════════════╦═══════════════╦══════════════╗${RESET}"
  echo -e "${CYAN}║ ID ║     CONTRASEÑA     ║   EXPIRA      ║   ESTADO     ║${RESET}"
  echo -e "${CYAN}╠════╬════════════════════╬═══════════════╬══════════════╣${RESET}"

  i=1
  today=$(date +%Y-%m-%d)
  while IFS='|' read -r pass exp; do
    pass=$(echo "$pass" | xargs)
    exp=$(echo "$exp" | xargs)

    if [[ "$exp" < "$today" ]]; then
      status="${RED}🔴 VENCIDO${RESET}"
    else
      status="${GREEN}🟢 ACTIVO${RESET}"
    fi

    printf "${CYAN}║%3s ${CYAN}║ ${YELLOW}%-18s${CYAN} ║ ${YELLOW}%-13s${CYAN} ║ %-12b${CYAN}║${RESET}\n" "$i" "$pass" "$exp" "$status"
    ((i++))
  done < "$USER_DB"

  echo -e "${CYAN}╚════╩════════════════════╩═══════════════╩══════════════╝${RESET}\n"
  read -p "🔙 Presione Enter para volver al menú..."
}

clean_expired_users() {
  today=$(date +%Y-%m-%d)
  updated=0
  cp "$CONFIG_FILE" "$BACKUP_FILE"
  while IFS='|' read -r pass exp; do
    if [[ "$exp" < "$today" ]]; then
      jq --arg pw "$pass" '.auth.config -= [$pw]' "$CONFIG_FILE" > temp && mv temp "$CONFIG_FILE"
      sed -i "/^$pass |/d" "$USER_DB"
      echo -e "${YELLOW}🧹 Usuario expirado eliminado: $pass${RESET}"
      updated=1
    fi
  done < "$USER_DB"
  [[ $updated -eq 1 ]] && {
    echo -e "${GREEN}✅ Limpieza finalizada.${RESET}"
    systemctl restart zivpn.service
  }
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
  [[ "$AUTOCLEAN" == "ON" ]] && clean_expired_users > /dev/null

  echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════╗"
  echo -e "║                   🧩 ZIVPN - PANEL DE USUARIOS UDP                   ║"
  echo -e "╠══════════════════════════════════════════════════════════════════════╣"
  echo -e "║ [1] ➕ Crear nuevo usuario (con expiración)                          ║"
  echo -e "║ [2] ❌ Remover usuario                                               ║"
  echo -e "║ [3] 🔁 Renovar usuario                                               ║"
  echo -e "║ [4] 📋 Información de los usuarios                                   ║"
  echo -e "║ [5] ▶️ Iniciar servicio                                              ║"
  echo -e "║ [6] 🔁 Reiniciar servicio                                            ║"
  echo -e "║ [7] ⏹️ Detener servicio                                              ║"
  if [[ "$AUTOCLEAN" == "ON" ]]; then
    echo -e "║ [8] 🧹 Eliminar usuarios vencidos            [${GREEN}ON${RESET}]                ║"
  else
    echo -e "║ [8] 🧹 Eliminar usuarios vencidos            [${RED}OFF${RESET}]               ║"
  fi
  echo -e "║ [9] 🚪 Salir                                                       ║"
  echo -e "╚══════════════════════════════════════════════════════════════════════╝${RESET}"

  read -p "📌 Seleccione una opción: " opc
  case $opc in
    1) add_user;;
    2) remove_user;;
    3) renew_user;;
    4) list_users;;
    5) start_service;;
    6) restart_service;;
    7) stop_service;;
    8) toggle_autoclean;;
    9) exit;;
    *) echo -e "${RED}❌ Opción inválida.${RESET}";;
  esac
done
