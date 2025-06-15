#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════╗
# ║        🛡️ PANEL DE GESTIÓN ZIVPN UDP TUNNEL – MEJORADO            ║
# ╚════════════════════════════════════════════════════════════════════╝

# 🎨 Colores
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

# 🧭 Detección de arquitectura
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
  ARCH_TEXT="AMD64"
elif [[ "$ARCH" == "aarch64" ]]; then
  ARCH_TEXT="ARM64"
else
  ARCH_TEXT="Desconocida"
fi

# ╔══════════════════════════════════════════════════╗
# ║ 🔍 FUNCIÓN: Mostrar puertos usados por zivpn      ║
# ╚══════════════════════════════════════════════════╝
mostrar_puertos_zivpn() {
  # Obtener PID del proceso zivpn si está corriendo
  PID=$(pgrep -f /usr/local/bin/zivpn)
  if [[ -z "$PID" ]]; then
    echo -e " Puertos: ${RED}No se pudo detectar proceso zivpn.${RESET}"
    return
  fi

  # Usar ss si está disponible
  if command -v ss &>/dev/null; then
    PUERTOS=$(ss -tulnp | grep "$PID" | awk '{print $5}' | cut -d':' -f2 | sort -u | tr '\n' ',' | sed 's/,$//')
  else
    # fallback a netstat
    PUERTOS=$(netstat -tulnp 2>/dev/null | grep "$PID" | awk '{print $4}' | rev | cut -d':' -f1 | rev | sort -u | tr '\n' ',' | sed 's/,$//')
  fi

  if [[ -z "$PUERTOS" ]]; then
    echo -e " Puertos: ${YELLOW}No se detectaron puertos abiertos.${RESET}"
  else
    echo -e " Puertos: ${GREEN}$PUERTOS${RESET}"
  fi
}

# ╔══════════════════════════════════════════════════╗
# ║ 🔍 FUNCIÓN: Mostrar puerto fijo e iptables       ║
# ╚══════════════════════════════════════════════════╝
mostrar_puerto_iptables() {
  local PUERTO="5667"
  local IPTABLES="6000-19999"
  echo -e " ${YELLOW}📛 Puerto:${RESET} ${GREEN}$PUERTO${RESET}   ${RED}🔥 Iptables:${RESET} ${CYAN}$IPTABLES${RESET}"
}

# ╔══════════════════════════════════════════════════╗
# ║ 🔍 FUNCIÓN: Mostrar estado del servicio ZIVPN    ║
# ╚══════════════════════════════════════════════════╝
mostrar_estado_servicio() {
  if [ -f /usr/local/bin/zivpn ] && [ -f /etc/systemd/system/zivpn.service ]; then
    systemctl is-active --quiet zivpn.service
    if [ $? -eq 0 ]; then
      echo -e " 🟢 Servicio ZIVPN UDP instalado y activo"
      mostrar_puerto_iptables
    else
      echo -e " 🟡 Servicio ZIVPN UDP instalado pero ${YELLOW}no activo${RESET}"
      mostrar_puerto_iptables
    fi
  else
    echo -e " 🔴 Servicio ZIVPN UDP ${RED}no instalado${RESET}"
  fi
}

# ╔══════════════════════════════════════════════════╗
# ║ 🔍 FUNCIÓN: Mostrar estado del fix iptables      ║
# ╚══════════════════════════════════════════════════╝
mostrar_estado_fix() {
  if [ -f /etc/zivpn-iptables-fix-applied ]; then
    echo -e "${GREEN}[ON]${RESET}"
  else
    echo -e "${RED}[OFF]${RESET}"
  fi
}

# ╔══════════════════════════════════════════════════╗
# ║ 🌀 Spinner                                        ║
# ╚══════════════════════════════════════════════════╝
spinner() {
  local pid=$!
  local delay=0.1
  local spinstr='|/-\'
  while ps -p $pid &>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
}

# ╔══════════════════════════════════════════════════╗
# ║ 📋 Menú principal                                ║
# ╚══════════════════════════════════════════════════╝
mostrar_menu() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "           🛠️ ${GREEN}ZIVPN UDP TUNNEL MANAGER${RESET}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

  # Mostrar arquitectura
  echo -e " 🔍 Arquitectura detectada: ${YELLOW}$ARCH_TEXT${RESET}"

  # Mostrar estado del servicio
  mostrar_estado_servicio

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -ne " ${YELLOW}1.${RESET} 🚀 Instalar Servicio UDP (${BLUE}AMD64${RESET})\n"
  echo -ne " ${YELLOW}2.${RESET} 📦 Instalar Servicio UDP (${GREEN}ARM64${RESET})\n"
  echo -ne " ${YELLOW}3.${RESET} ❌ Desinstalar Servicio UDP\n"
  echo -ne " ${YELLOW}4.${RESET} 🔁 Aplicar Fix Persistente iptables $(mostrar_estado_fix)\n"
  echo -ne " ${YELLOW}5.${RESET} 🔙 Salir\n"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -ne "📤 ${BLUE}Selecciona una opción:${RESET} "
}

# ╔══════════════════════════════════════════════════╗
# ║ 🚀 FUNCIONES DE INSTALACIÓN, DESINSTALACIÓN      ║
# ╚══════════════════════════════════════════════════╝

instalar_amd() {
  clear
  echo -e "${GREEN}🚀 Descargando instalador para AMD64...${RESET}"
  wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/install-amd.sh -O install-amd.sh &
  spinner
  if [[ ! -f install-amd.sh ]]; then
    echo -e "${RED}❌ Error: No se pudo descargar el archivo.${RESET}"
    read -p "Presiona Enter para continuar..."
    return
  fi
  echo -e "${GREEN}🔧 Ejecutando instalación...${RESET}"
  bash install-amd.sh
  rm -f install-amd.sh
  echo -e "${GREEN}✅ Instalación completada.${RESET}"
  read -p "Presiona Enter para continuar..."
}

instalar_arm() {
  clear
  echo -e "${GREEN}📦 Descargando instalador para ARM64...${RESET}"
  wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/install-arm.sh -O install-arm.sh &
  spinner
  if [[ ! -f install-arm.sh ]]; then
    echo -e "${RED}❌ Error: No se pudo descargar el archivo.${RESET}"
    read -p "Presiona Enter para continuar..."
    return
  fi
  echo -e "${GREEN}🔧 Ejecutando instalación...${RESET}"
  bash install-arm.sh
  rm -f install-arm.sh
  echo -e "${GREEN}✅ Instalación completada.${RESET}"
  read -p "Presiona Enter para continuar..."
}

desinstalar_udp() {
  clear
  echo -e "${RED}🧹 Descargando script de desinstalación...${RESET}"
  wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/uninstall.sh -O uninstall.sh &
  spinner
  if [[ ! -f uninstall.sh ]]; then
    echo -e "${RED}❌ Error: No se pudo descargar el archivo.${RESET}"
    read -p "Presiona Enter para continuar..."
    return
  fi
  echo -e "${RED}⚙️ Ejecutando desinstalación...${RESET}"
  bash uninstall.sh
  rm -f uninstall.sh
  echo -e "${GREEN}✅ Desinstalación completada.${RESET}"
  read -p "Presiona Enter para continuar..."
}

# ╔══════════════════════════════════════════════════╗
# ║ 🛠️ FUNCIÓN: Aplicar fix iptables persistente    ║
# ╚══════════════════════════════════════════════════╝
fix_iptables_zivpn() {
  clear
  echo -e "${CYAN}🔧 Aplicando fix persistente iptables para ZIVPN...${RESET}"
  wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/zivpn-iptables-fix.sh -O zivpn-iptables-fix.sh
  if [[ ! -f zivpn-iptables-fix.sh ]]; then
    echo -e "${RED}❌ Error: No se pudo descargar el fix.${RESET}"
    read -p "Presiona Enter para continuar..."
    return
  fi
  bash zivpn-iptables-fix.sh
  local res=$?
  rm -f zivpn-iptables-fix.sh
  if [[ $res -eq 0 ]]; then
    # Crear archivo indicador para ON
    touch /etc/zivpn-iptables-fix-applied 2>/dev/null || echo -e "${YELLOW}⚠️ No se pudo crear archivo indicador de estado.${RESET}"
    echo -e "${GREEN}✅ Fix aplicado correctamente.${RESET}"
  else
    echo -e "${RED}❌ Ocurrió un error al aplicar el fix.${RESET}"
  fi
  read -p "Presiona Enter para continuar..."
}

# 🔁 Bucle del menú principal
while true; do
  clear
  mostrar_menu
  read -r opcion
  case $opcion in
    1) instalar_amd ;;
    2) instalar_arm ;;
    3) desinstalar_udp ;;
    4) fix_iptables_zivpn ;;
    5) echo -e "${YELLOW}👋 ¡Hasta luego!${RESET}"; exit 0 ;;
    *) echo -e "${RED}❌ Opción inválida. Intenta de nuevo.${RESET}"; sleep 2 ;;
  esac
done
