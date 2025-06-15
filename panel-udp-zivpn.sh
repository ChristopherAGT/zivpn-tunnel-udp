#!/bin/bash

# ╔════════════════════════════════════════════════════════════╗
# ║        🛡️ ZIVPN - PANEL DE GESTIÓN DE USUARIOS (PASS)      ║
# ╚════════════════════════════════════════════════════════════╝

# 🎨 Colores
RED="\e[31m" GREEN="\e[32m" YELLOW="\e[33m" CYAN="\e[36m" BLUE="\e[34m" RESET="\e[0m"

DB="/etc/zivpn/usuarios.db"
CONFIG="/etc/zivpn/config.json"
[ ! -f "$DB" ] && touch "$DB"
[ ! -f "$CONFIG" ] && echo '{"config":[]}' > "$CONFIG"

# 🔄 Actualiza config.json solo con usuarios no vencidos
actualizar_config() {
    local config_list=()
    local now=$(date +%s)
    while IFS='|' read -r usuario exp; do
        exp_ts=$(date -d "$exp" +%s 2>/dev/null)
        [ "$exp_ts" -gt "$now" ] && config_list+=("\"$usuario\"")
    done < "$DB"
    echo -e "{\n  \"config\": [$(IFS=,; echo "${config_list[*]}")]\n}" > "$CONFIG"
    systemctl restart zivpn.service &>/dev/null
}

# 📋 Muestra los usuarios (contraseñas activas)
mostrar_usuarios() {
    echo -e "\n${CYAN}🔐 Usuarios actuales de ZIVPN:${RESET}"
    echo -e "────────────────────────────────────────────────────"
    echo -e "👤 Usuario               📅 Expira       📌 Estado"
    echo -e "────────────────────────────────────────────────────"
    local now=$(date +%s)
    while IFS='|' read -r usuario exp; do
        exp_ts=$(date -d "$exp" +%s 2>/dev/null)
        estado=$([ "$exp_ts" -gt "$now" ] && echo "${GREEN}Activo${RESET}" || echo "${RED}Vencido${RESET}")
        printf "%-22s %-14s %b\n" "$usuario" "$exp" "$estado"
    done < "$DB"
    echo
}

# ➕ Crear usuario (contraseña como usuario)
crear_usuario() {
    echo -e "${YELLOW}➕ Crear nuevo usuario (contraseña válida):${RESET}"
    read -rp "👤 Usuario (será su contraseña): " usuario
    read -rp "⏳ Días de duración: " dias
    exp=$(date -d "+$dias days" +"%d-%m-%Y")
    echo "$usuario|$exp" >> "$DB"
    actualizar_config
    echo -e "${GREEN}✅ Usuario '$usuario' creado, expira el $exp.${RESET}"
}

# ❌ Remover usuario
remover_usuario() {
    mostrar_usuarios
    echo -e "${YELLOW}❌ Ingrese el usuario a eliminar (0 para cancelar):${RESET}"
    read -rp "🗑️ Usuario: " target
    [ "$target" == "0" ] && return
    if grep -q "^$target|" "$DB"; then
        sed -i "/^$target|/d" "$DB"
        actualizar_config
        echo -e "${GREEN}✅ Usuario eliminado.${RESET}"
    else
        echo -e "${RED}⚠️ Usuario no encontrado.${RESET}"
    fi
}

# 🔁 Renovar usuario
renovar_usuario() {
    mostrar_usuarios
    echo -e "${YELLOW}🔁 Ingrese el usuario a renovar:${RESET}"
    read -rp "👤 Usuario: " target
    if grep -q "^$target|" "$DB"; then
        read -rp "📅 Nuevos días de duración: " dias
        new_exp=$(date -d "+$dias days" +"%d-%m-%Y")
        sed -i "/^$target|/d" "$DB"
        echo "$target|$new_exp" >> "$DB"
        actualizar_config
        echo -e "${GREEN}✅ Usuario renovado hasta $new_exp.${RESET}"
    else
        echo -e "${RED}⚠️ Usuario no encontrado.${RESET}"
    fi
}

# ▶️ Iniciar servicio
iniciar_servicio() {
    systemctl start zivpn.service && echo -e "${GREEN}✅ Servicio iniciado.${RESET}" || echo -e "${RED}❌ Error al iniciar.${RESET}"
}

# 🔁 Reiniciar servicio
reiniciar_servicio() {
    systemctl restart zivpn.service && echo -e "${GREEN}✅ Servicio reiniciado.${RESET}" || echo -e "${RED}❌ Error al reiniciar.${RESET}"
}

# ⏹️ Detener servicio
detener_servicio() {
    systemctl stop zivpn.service && echo -e "${GREEN}✅ Servicio detenido.${RESET}" || echo -e "${RED}❌ Error al detener.${RESET}"
}

# 🧭 Menú principal
while true; do
    echo -e "${BLUE}
╔════════════════════════════════════════════════╗
║       🧩 ZIVPN - PANEL DE USUARIOS UDP         ║
╠════════════════════════════════════════════════╣
║ [1] ➕ Crear nuevo usuario (con expiración)     ║
║ [2] ❌ Remover usuario                          ║
║ [3] 🔁 Renovar usuario                          ║
║ [4] 📋 Información de los usuarios              ║
║ [5] ▶️ Iniciar servicio                         ║
║ [6] 🔁 Reiniciar servicio                       ║
║ [7] ⏹️ Detener servicio                        ║
║ [8] 🚪 Salir                                    ║
╚════════════════════════════════════════════════╝${RESET}"
    read -rp "📤 Seleccione una opción [1-8]: " opcion
    case $opcion in
        1) crear_usuario ;;
        2) remover_usuario ;;
        3) renovar_usuario ;;
        4) mostrar_usuarios; read -rp "🔙 Presione Enter para volver al menú..." ;;
        5) iniciar_servicio ;;
        6) reiniciar_servicio ;;
        7) detener_servicio ;;
        8) echo -e "${YELLOW}👋 Saliendo... Hasta pronto.${RESET}"; exit 0 ;;
        *) echo -e "${RED}❌ Opción inválida.${RESET}" ;;
    esac
done
