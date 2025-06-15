#!/bin/bash

# ╔════════════════════════════════════════════════════════════╗
# ║        🛡️ ZIVPN - PANEL DE GESTIÓN DE USUARIOS (PASS)      ║
# ╚════════════════════════════════════════════════════════════╝

# 🎨 Colores
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; CYAN="\e[36m"; BLUE="\e[34m"; RESET="\e[0m"; BOLD="\e[1m"

# 📁 Archivos base
DB="/etc/zivpn/usuarios.db"
CONFIG="/etc/zivpn/config.json"
AUTO_CLEAN_FILE="/etc/zivpn/auto-clean.conf"
mkdir -p /etc/zivpn
[ ! -f "$DB" ] && touch "$DB"
[ ! -f "$CONFIG" ] && echo '{"config":[]}' > "$CONFIG"
[ ! -f "$AUTO_CLEAN_FILE" ] && echo "OFF" > "$AUTO_CLEAN_FILE"

# 🔄 Actualiza config.json con usuarios activos
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

# 📋 Mostrar usuarios decorado
mostrar_usuarios() {
    echo -e "\n${CYAN}${BOLD}🔐 Usuarios actuales de ZIVPN:${RESET}"
    printf "${BLUE}╔════════════╦═══════════════╦════════════╗\n"
    printf "║  Usuario   ║  Expira       ║  Estado    ║\n"
    printf "╠════════════╬═══════════════╬════════════╣${RESET}\n"
    local now=$(date +%s)
    while IFS='|' read -r usuario exp; do
        exp_ts=$(date -d "$exp" +%s 2>/dev/null)
        estado=$([ "$exp_ts" -gt "$now" ] && echo -e "${GREEN}Activo${RESET}" || echo -e "${RED}Vencido${RESET}")
        printf "${BLUE}║ %-10s ║ %-13s ║ %-10b ║\n" "$usuario" "$exp" "$estado"
    done < "$DB"
    printf "${BLUE}╚════════════╩═══════════════╩════════════╝${RESET}\n\n"
}

# ➕ Crear usuario
crear_usuario() {
    echo -e "${YELLOW}➕ Crear nuevo usuario (contraseña válida):${RESET}"
    read -rp "👤 Usuario (será su contraseña): " usuario
    [ -z "$usuario" ] && { echo -e "${RED}⚠️ El campo de usuario no puede estar vacío.${RESET}"; return; }

    read -rp "⏳ Días de duración: " dias
    [[ ! "$dias" =~ ^[0-9]+$ ]] && { echo -e "${RED}⚠️ Días debe ser un número.${RESET}"; return; }

    exp=$(date -d "+$dias days" +"%d-%m-%Y")
    cp "$DB" "$DB.bak"
    echo "$usuario|$exp" >> "$DB"
    [ "$(cat $AUTO_CLEAN_FILE)" == "ON" ] && limpiar_vencidos_silencioso
    actualizar_config
    echo -e "${GREEN}✅ Usuario '$usuario' creado, expira el $exp.${RESET}"
    mostrar_usuarios
}

# ❌ Remover usuario
remover_usuario() {
    mostrar_usuarios
    echo -e "${YELLOW}❌ Ingrese el usuario a eliminar (0 para cancelar):${RESET}"
    read -rp "🗑️ Usuario: " target
    [ "$target" == "0" ] && return
    if grep -q "^$target|" "$DB"; then
        cp "$DB" "$DB.bak"
        sed -i "/^$target|/d" "$DB"
        actualizar_config
        echo -e "${GREEN}✅ Usuario eliminado.${RESET}"
    else
        echo -e "${RED}⚠️ Usuario no encontrado.${RESET}"
    fi
    mostrar_usuarios
}

# 🔁 Renovar usuario
renovar_usuario() {
    mostrar_usuarios
    echo -e "${YELLOW}🔁 Ingrese el usuario a renovar:${RESET}"
    read -rp "👤 Usuario: " target
    if grep -q "^$target|" "$DB"; then
        read -rp "📅 Nuevos días de duración: " dias
        [[ ! "$dias" =~ ^[0-9]+$ ]] && { echo -e "${RED}⚠️ Días inválidos.${RESET}"; return; }
        new_exp=$(date -d "+$dias days" +"%d-%m-%Y")
        cp "$DB" "$DB.bak"
        sed -i "/^$target|/d" "$DB"
        echo "$target|$new_exp" >> "$DB"
        [ "$(cat $AUTO_CLEAN_FILE)" == "ON" ] && limpiar_vencidos_silencioso
        actualizar_config
        echo -e "${GREEN}✅ Usuario renovado hasta $new_exp.${RESET}"
    else
        echo -e "${RED}⚠️ Usuario no encontrado.${RESET}"
    fi
    mostrar_usuarios
}

# 🧹 Limpiar vencidos (manual)
limpiar_vencidos() {
    local now=$(date +%s)
    cp "$DB" "$DB.bak"
    awk -F'|' -v now="$now" '{
        cmd="date -d "$2" +%s"; cmd | getline t; close(cmd);
        if(t>now) print
    }' "$DB.bak" > "$DB"
    actualizar_config
    echo -e "${GREEN}🧹 Usuarios vencidos eliminados.${RESET}"
}

# 🧹 Silencioso (auto-clean)
limpiar_vencidos_silencioso() {
    local now=$(date +%s)
    awk -F'|' -v now="$now" '{
        cmd="date -d "$2" +%s"; cmd | getline t; close(cmd);
        if(t>now) print
    }' "$DB" > "$DB.tmp" && mv "$DB.tmp" "$DB"
}

# ⚙️ Alternar limpieza automática
toggle_auto_clean() {
    estado=$(cat "$AUTO_CLEAN_FILE")
    if [ "$estado" == "OFF" ]; then
        echo "ON" > "$AUTO_CLEAN_FILE"
        echo -e "${GREEN}✅ Limpieza automática activada.${RESET}"
    else
        echo "OFF" > "$AUTO_CLEAN_FILE"
        echo -e "${YELLOW}🔕 Limpieza automática desactivada.${RESET}"
    fi
}

# ▶️ Control de servicio
iniciar_servicio() { systemctl start zivpn.service && echo -e "${GREEN}✅ Servicio iniciado.${RESET}" || echo -e "${RED}❌ Error al iniciar.${RESET}"; }
reiniciar_servicio() { systemctl restart zivpn.service && echo -e "${GREEN}✅ Servicio reiniciado.${RESET}" || echo -e "${RED}❌ Error al reiniciar.${RESET}"; }
detener_servicio() { systemctl stop zivpn.service && echo -e "${GREEN}✅ Servicio detenido.${RESET}" || echo -e "${RED}❌ Error al detener.${RESET}"; }

# ⚠️ Aviso de vencidos
vencidos=$(awk -F'|' -v now=$(date +%s) '{cmd="date -d "$2" +%s"; cmd | getline t; close(cmd); if(t<now) c++} END{print c}' "$DB")
[ "$vencidos" -gt 0 ] && echo -e "${YELLOW}⚠️ Hay $vencidos usuario(s) vencido(s). Usa [8] para limpiarlos.${RESET}"

# Estado de limpieza automática
estado_clean=$(cat "$AUTO_CLEAN_FILE")
estado_text=$([ "$estado_clean" == "ON" ] && echo "${GREEN}[ON]${RESET}" || echo "${RED}[OFF]${RESET}")

# 🧭 Menú principal
while true; do
    echo -e "${BLUE}
╔═══════════════════════════════════════════════════════╗
║             🧩 ZIVPN - PANEL DE USUARIOS UDP           ║
╠═══════════════════════════════════════════════════════╣
║ [1] ➕ Crear nuevo usuario (con expiración)            ║
║ [2] ❌ Remover usuario                                 ║
║ [3] 🔁 Renovar usuario                                 ║
║ [4] 📋 Información de los usuarios                     ║
║ [5] ▶️ Iniciar servicio                                ║
║ [6] 🔁 Reiniciar servicio                              ║
║ [7] ⏹️ Detener servicio                               ║
║ [8] 🧹 Eliminar usuarios vencidos   $estado_text         ║
║ [9] 🚪 Salir                                           ║
╚═══════════════════════════════════════════════════════╝${RESET}"
    read -rp $'\n📤 Seleccione una opción [1-9]: ' opcion
    case $opcion in
        1) crear_usuario ;;
        2) remover_usuario ;;
        3) renovar_usuario ;;
        4) mostrar_usuarios; read -rp "🔙 Presione Enter para volver al menú..." ;;
        5) iniciar_servicio ;;
        6) reiniciar_servicio ;;
        7) detener_servicio ;;
        8)
            echo -e "\n${CYAN}¿Qué desea hacer con los usuarios vencidos?${RESET}"
            echo "1) 🧹 Eliminar manualmente"
            echo "2) 🔄 Alternar limpieza automática (ON/OFF)"
            read -rp "Seleccione [1-2]: " subopt
            case $subopt in
                1) limpiar_vencidos ;;
                2) toggle_auto_clean ;;
                *) echo -e "${RED}❌ Opción inválida.${RESET}" ;;
            esac
            ;;
        9) echo -e "${YELLOW}👋 Saliendo... Hasta pronto.${RESET}"; exit 0 ;;
        *) echo -e "${RED}❌ Opción inválida.${RESET}" ;;
    esac
    estado_clean=$(cat "$AUTO_CLEAN_FILE")
    estado_text=$([ "$estado_clean" == "ON" ] && echo "${GREEN}[ON]${RESET}" || echo "${RED}[OFF]${RESET}")
done
