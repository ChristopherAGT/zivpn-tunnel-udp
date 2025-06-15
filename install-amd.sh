#!/bin/bash

# ╔════════════════════════════════════════════════════════════╗
# ║   🚀 ZIVPN UDP MODULE INSTALLER                            ║
# ║   👤 Autor: Zahid Islam                                    ║
# ║   🛠️ Instala el servicio UDP de ZIVPN en el servidor       ║
# ╚════════════════════════════════════════════════════════════╝

# 🎨 Colores para mejor presentación
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
RESET="\e[0m"

# ╔════════════════════════════════════════════════════════════╗
# ║  📦 ACTUALIZANDO EL SISTEMA                                ║
# ╚════════════════════════════════════════════════════════════╝
echo -e "${CYAN}🔄 Actualizando paquetes del sistema...${RESET}"
sudo apt-get update && sudo apt-get upgrade -y

# ╔════════════════════════════════════════════════════════════╗
# ║  ⬇️ DESCARGANDO ZIVPN UDP                                 ║
# ╚════════════════════════════════════════════════════════════╝
echo -e "${CYAN}📥 Descargando binario de ZIVPN...${RESET}"
systemctl stop zivpn.service &>/dev/null
wget -q https://github.com/ChristopherAGT/zivpn-tunnel-udp/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

echo -e "${CYAN}📁 Preparando configuración...${RESET}"
mkdir -p /etc/zivpn
wget -q https://raw.githubusercontent.com/ChristopherAGT/zivpn-tunnel-udp/main/config.json -O /etc/zivpn/config.json

# ╔════════════════════════════════════════════════════════════╗
# ║  🔐 GENERANDO CERTIFICADOS SSL                             ║
# ╚════════════════════════════════════════════════════════════╝
echo -e "${CYAN}🔐 Generando certificados SSL...${RESET}"
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
-subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" \
-keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"

# ╔════════════════════════════════════════════════════════════╗
# ║  ⚙️ OPTIMIZANDO PARÁMETROS DEL SISTEMA                     ║
# ╚════════════════════════════════════════════════════════════╝
sysctl -w net.core.rmem_max=16777216 &>/dev/null
sysctl -w net.core.wmem_max=16777216 &>/dev/null

# ╔════════════════════════════════════════════════════════════╗
# ║  🧩 CREANDO SERVICIO SYSTEMD                               ║
# ╚════════════════════════════════════════════════════════════╝
if [ -f /etc/systemd/system/zivpn.service ]; then
    echo -e "${YELLOW}⚠️ El servicio ZIVPN ya existe. Se omitirá su creación.${RESET}"
else
    echo -e "${CYAN}🔧 Configurando servicio systemd...${RESET}"
    cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=ZIVPN UDP VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
fi

# ╔════════════════════════════════════════════════════════════╗
# ║  🔑 CONFIGURANDO CONTRASEÑAS                               ║
# ╚════════════════════════════════════════════════════════════╝
echo -e "${YELLOW}🔑 Ingresa las contraseñas separadas por comas (Ej: pass1,pass2)"
read -p "🔐 Contraseñas (por defecto: zivpn): " input_config

if [ -n "$input_config" ]; then
    IFS=',' read -r -a config <<< "$input_config"
    [ ${#config[@]} -eq 1 ] && config+=(${config[0]})
else
    config=("zivpn")
fi

new_config_str="\"config\": [$(printf "\"%s\"," "${config[@]}" | sed 's/,$//')]"
sed -i -E "s/\"config\": ?.*/${new_config_str}/g" /etc/zivpn/config.json

# ╔════════════════════════════════════════════════════════════╗
# ║  🚀 INICIANDO Y HABILITANDO SERVICIO                       ║
# ╚════════════════════════════════════════════════════════════╝
systemctl enable zivpn.service
systemctl start zivpn.service

# ╔════════════════════════════════════════════════════════════╗
# ║  🌐 CONFIGURANDO IPTABLES Y FIREWALL                       ║
# ╚════════════════════════════════════════════════════════════╝
iface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
if ! iptables -t nat -C PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 &>/dev/null; then
    iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667
else
    echo -e "${YELLOW}⚠️ La regla iptables ya existe. Se omite agregarla nuevamente.${RESET}"
fi

ufw allow 6000:19999/udp
ufw allow 5667/udp

# ╔════════════════════════════════════════════════════════════╗
# ║  ✅ FINALIZADO                                             ║
# ╚════════════════════════════════════════════════════════════╝
rm -f install-amd.sh install-amd.tmp install-amd.log &>/dev/null
echo -e "${GREEN}✅ ZIVPN UDP instalado correctamente.${RESET}"
