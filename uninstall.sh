#!/bin/bash

# ╔════════════════════════════════════════════════════════════╗
# ║   ❌ ZIVPN UNINSTALLER                                     ║
# ║   🧽 Limpieza completa del sistema                         ║
# ╚════════════════════════════════════════════════════════════╝

# 🎨 Colores
GREEN="\e[32m"
RED="\e[31m"
CYAN="\e[36m"
YELLOW="\e[33m"
RESET="\e[0m"

clear
echo -e "${CYAN}🔧 Desinstalando ZiVPN...${RESET}"

# ╔════════════════════════════════════════════════════════════╗
# ║   🛑 DETENIENDO SERVICIOS                                  ║
# ╚════════════════════════════════════════════════════════════╝
systemctl stop zivpn.service &>/dev/null
systemctl stop zivpn_backfill.service &>/dev/null
systemctl disable zivpn.service &>/dev/null
systemctl disable zivpn_backfill.service &>/dev/null

# ╔════════════════════════════════════════════════════════════╗
# ║   🧽 ELIMINANDO ARCHIVOS Y BINARIOS                        ║
# ╚════════════════════════════════════════════════════════════╝
rm -f /etc/systemd/system/zivpn.service
rm -f /etc/systemd/system/zivpn_backfill.service
rm -rf /etc/zivpn
rm -f /usr/local/bin/zivpn
killall zivpn &>/dev/null

# ╔════════════════════════════════════════════════════════════╗
# ║   🔥 ELIMINANDO REGLAS IPTABLES DEL FIX                    ║
# ╚════════════════════════════════════════════════════════════╝
echo -e "${CYAN}🧯 Eliminando reglas de iptables del fix...${RESET}"
iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
iptables -t nat -D PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 &>/dev/null

# ╔════════════════════════════════════════════════════════════╗
# ║   🗑️ ELIMINANDO INDICADOR DEL FIX                          ║
# ╚════════════════════════════════════════════════════════════╝
rm -f /etc/zivpn-iptables-fix-applied

# ╔════════════════════════════════════════════════════════════╗
# ║   📋 COMPROBANDO ESTADO FINAL                              ║
# ╚════════════════════════════════════════════════════════════╝
if pgrep "zivpn" &>/dev/null; then
    echo -e "${RED}⚠️  El proceso sigue activo.${RESET}"
else
    echo -e "${GREEN}✅ Proceso detenido correctamente.${RESET}"
fi

if [ -e "/usr/local/bin/zivpn" ]; then
    echo -e "${YELLOW}⚠️  Archivos aún presentes. Intente nuevamente.${RESET}"
else
    echo -e "${GREEN}✅ Archivos eliminados exitosamente.${RESET}"
fi

# ╔════════════════════════════════════════════════════════════╗
# ║   🧼 LIMPIEZA DE CACHE Y SWAP                              ║
# ╚════════════════════════════════════════════════════════════╝
echo -e "${CYAN}🧹 Limpiando caché y reiniciando swap...${RESET}"
echo 3 > /proc/sys/vm/drop_caches
sysctl -w vm.drop_caches=3 &>/dev/null
swapoff -a && swapon -a

# ╔════════════════════════════════════════════════════════════╗
# ║   ✅ FINALIZADO                                            ║
# ╚════════════════════════════════════════════════════════════╝
echo -e "${GREEN}✅ ZiVPN desinstalado correctamente.${RESET}"
