#!/bin/bash

# ╔════════════════════════════════════════════════════╗
# ║        🛡️ PANEL DE GESTIÓN ZIVPN UDP TUNNEL       ║
# ╚════════════════════════════════════════════════════╝

# 🎨 Colores
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

# 🧹 Limpia la pantalla
clear

# 📋 Función de menú principal
mostrar_menu() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "           🛠️ ${GREEN}ZIVPN UDP TUNNEL MANAGER${RESET}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e " ${YELLOW}1.${RESET} 🚀 Instalar Servicio UDP (${BLUE}AMD64${RESET})"
  echo -e " ${YELLOW}2.${RESET} 📦 Instalar Servicio UDP (${GREEN}ARM64${RESET})"
  echo -e " ${YELLOW}3.${RESET} ❌ Desinstalar Servicio UDP"
  echo -e " ${YELLOW}4.${RESET} 🔙 Salir"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -ne "📤 ${BLUE}Selecciona una opción:${RESET} "
}

# 🛠️ Funciones
instalar_amd() {
  echo -e "\n${GREEN}🚀 Instalando ZIVPN para arquitectura AMD64...${RESET}"
  wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/install-amd.sh -O install-amd.sh \
  && bash install-amd.sh \
  && rm -f install-amd.sh
  echo -e "${GREEN}✅ Instalación completada.${RESET}"
  echo ""
  read -p "Presiona Enter para continuar..." 
}

instalar_arm() {
  echo -e "\n${GREEN}📦 Instalando ZIVPN para arquitectura ARM64...${RESET}"
  wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/install-arm.sh -O install-arm.sh \
  && bash install-arm.sh \
  && rm -f install-arm.sh
  echo -e "${GREEN}✅ Instalación completada.${RESET}"
  echo ""
  read -p "Presiona Enter para continuar..." 
}

desinstalar_udp() {
  echo -e "\n${RED}🧹 Desinstalando ZIVPN UDP Tunnel...${RESET}"
  wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/uninstall.sh -O uninstall.sh \
  && bash uninstall.sh \
  && rm -f uninstall.sh
  echo -e "${GREEN}✅ Desinstalación completada.${RESET}"
  echo ""
  read -p "Presiona Enter para continuar..." 
}

# 🔁 Bucle principal
while true; do
  clear
  mostrar_menu
  read opcion
  case $opcion in
    1) instalar_amd ;;
    2) instalar_arm ;;
    3) desinstalar_udp ;;
    4) echo -e "${YELLOW}👋 ¡Hasta luego!${RESET}"; exit 0 ;;
    *) echo -e "${RED}❌ Opción inválida. Intenta de nuevo.${RESET}"; sleep 2 ;;
  esac
done
