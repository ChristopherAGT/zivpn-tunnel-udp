#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════════╗
# ║       ❌  ZIVPN UDP UNINSTALLER                                      ║
# ║       🧽 Limpieza completa del sistema y del panel de administración ║
# ║       👤 Autor: Zahid Islam / Adaptado por Christopher               ║
# ╚══════════════════════════════════════════════════════════════════════╝

# 🎨 Colores
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
MAGENTA="\033[1;35m"
RESET="\033[0m"

# Función para imprimir secciones
print_section() {
  local title="$1"
  echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════╗${RESET}"
  printf "${MAGENTA}║ %-66s ║\n" "$title"
  echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════╝${RESET}"
}

clear
print_section "🧹 INICIANDO DESINSTALACIÓN DE ZiVPN"

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🛑 DETENIENDO SERVICIOS"
systemctl stop zivpn.service &>/dev/null
systemctl stop zivpn_backfill.service &>/dev/null
systemctl disable zivpn.service &>/dev/null
systemctl disable zivpn_backfill.service &>/dev/null

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🧽 ELIMINANDO BINARIOS Y ARCHIVOS DE CONFIGURACIÓN"
rm -f /etc/systemd/system/zivpn.service
rm -f /etc/systemd/system/zivpn_backfill.service
rm -rf /etc/zivpn
rm -f /usr/local/bin/zivpn
killall zivpn &>/dev/null

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🔥 ELIMINANDO REGLAS DE IPTABLES"
iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
iptables -t nat -D PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 &>/dev/null

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🗑️ ELIMINANDO INDICADORES Y FIXES"
rm -f /etc/zivpn-iptables-fix-applied

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🧨 ELIMINANDO PANEL DE ADMINISTRACIÓN"
rm -f /usr/local/bin/menu-zivpn
rm -f /etc/zivpn/usuarios.db
rm -f /etc/zivpn/autoclean.conf
rm -f /etc/systemd/system/zivpn-autoclean.timer
rm -f /etc/systemd/system/zivpn-autoclean.service
systemctl daemon-reexec &>/dev/null
systemctl daemon-reload &>/dev/null

# ╔════════════════════════════════════════════════════════════════════╗
print_section "📋 VERIFICANDO ESTADO FINAL"
if pgrep "zivpn" &>/dev/null; then
  echo -e "${RED}⚠️  El proceso sigue activo.${RESET}"
else
  echo -e "${GREEN}✅ Proceso detenido correctamente.${RESET}"
fi

if [ -e "/usr/local/bin/zivpn" ]; then
  echo -e "${YELLOW}⚠️  Binario aún presente. Intente nuevamente.${RESET}"
else
  echo -e "${GREEN}✅ Binario eliminado correctamente.${RESET}"
fi

if [ -f /usr/local/bin/menu-zivpn ]; then
  echo -e "${RED}⚠️  El panel no fue eliminado.${RESET}"
else
  echo -e "${GREEN}✅ Panel eliminado exitosamente.${RESET}"
fi

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🧼 LIMPIEZA DE CACHÉ Y SWAP"
echo 3 > /proc/sys/vm/drop_caches
sysctl -w vm.drop_caches=3 &>/dev/null
swapoff -a && swapon -a

# ╔════════════════════════════════════════════════════════════════════╗
print_section "🏁 FINALIZADO"
echo -e "${GREEN}✅ UDP ZiVPN y su panel han sido desinstalados correctamente.${RESET}"
