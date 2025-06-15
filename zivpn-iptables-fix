#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════╗
# ║   🔐 FIX REGLAS IPTABLES PERSISTENTES PARA ZIVPN UDP TUNNEL     ║
# ║   👤 Autor: ChristopherAGT                                       ║
# ║   🛠️ Soluciona la pérdida de reglas iptables tras reinicio      ║
# ╚══════════════════════════════════════════════════════════════════╝

# 🎨 Colores
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
RESET="\033[0m"

echo -e "${CYAN}🔍 Detectando interfaz de red...${RESET}"
iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

if [[ -z "$iface" ]]; then
  echo -e "${RED}❌ No se pudo detectar interfaz de red. Abortando.${RESET}"
  exit 1
fi

echo -e "${CYAN}🌐 Interfaz detectada: ${YELLOW}$iface${RESET}"

# 📌 Aplicar la regla iptables si no existe
echo -e "${CYAN}🧪 Verificando regla iptables para ZIVPN...${RESET}"
if iptables -t nat -C PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null; then
  echo -e "${YELLOW}⚠️ La regla ya existe. No se aplicará nuevamente.${RESET}"
else
  echo -e "${GREEN}✅ Agregando regla iptables para ZIVPN...${RESET}"
  iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667
fi

# 🔥 Abrir puertos con UFW si está presente
if command -v ufw &>/dev/null; then
  echo -e "${CYAN}🔓 Configurando UFW...${RESET}"
  ufw allow 6000:19999/udp &>/dev/null
  ufw allow 5667/udp &>/dev/null
fi

# 📦 Instalar iptables-persistent si no existe
if ! dpkg -s iptables-persistent &>/dev/null; then
  echo -e "${CYAN}📦 Instalando iptables-persistent para mantener reglas...${RESET}"
  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
  echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
  apt-get install -y iptables-persistent &>/dev/null
fi

# 💾 Guardar reglas para reinicio
echo -e "${CYAN}💾 Guardando reglas para reinicio...${RESET}"
iptables-save > /etc/iptables/rules.v4

echo -e "${GREEN}✅ Reglas aplicadas y guardadas correctamente.${RESET}"
