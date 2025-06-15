#!/bin/bash

# ╔════════════════════════════════════════════════════════════════════╗
# ║        🛡️ ZIVPN - PANEL DE GESTIÓN DE USUARIOS (PASSWORD)         ║
# ╚════════════════════════════════════════════════════════════════════╝

# 🎨 Colores
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"; CYAN="\e[36m"; BLUE="\e[34m"; RESET="\e[0m"

# 📁 Rutas
DB="/etc/zivpn/usuarios.db"
CONFIG="/etc/zivpn/config.json"
AUTO_CLEAN_FILE="/etc/zivpn/auto-clean.conf"
mkdir -p /etc/zivpn
[ ! -f "$DB" ] && touch "$DB"
[ ! -f "$CONFIG" ] && echo '{"config":[]}' > "$CONFIG"
[ ! -f "$AUTO_CLEAN_FILE" ] && echo "OFF" > "$AUTO_CLEAN_FILE"

# 🔄 Actualizar config.json
actualizar_config() {
    local usuarios=()
    local now=$(date +%s)
    while IFS='|' read -r usuario exp; do
        exp_ts=$(date -d "$exp" +%s 2>/dev/null)
        [ "$exp_ts" -gt "$now" ] && usuarios+=("\"$usuario\"")
    done < "$DB"
    echo -e "{\n  \"config\": [$(IFS=,; echo "${usuarios[*]}")]\n}" > "$CONFIG"
    systemctl restart zivpn.service &>/dev/null
}

# 📋 Mostrar usuarios (decorado)
mostrar_usuarios() {
    local now=$(date +%s)
    echo -e "\n${CYAN}📋 Lista de usuarios registrados:${RESET}"
    printf "${BLUE}╔════════════╦══════════════╦═══════════╗\n"
    printf "║  Usuario   ║  Expira      ║  Estado   ║\n"
    printf "╠════════════╬══════════════╬═══════════╣${RESET}\n"
    while IFS='|' read -r usuario exp; do
        exp_ts=$(date -d "$exp" +%s 2>/dev/null)
        estado=$([ "$exp_ts" -gt "$now" ] && echo "${GREEN}Activo${RESET}" || echo "${RED}Vencido${RESET}")
        printf "║ %-10s ║ %-12s ║ %-9b ║\n" "$usuario" "$exp" "$estado"
    done < "$DB"
    printf "${BLUE}╚════════════╩══════════════╩═══════════╝${RESET}\n"
}

# ➕ Crear usuario
crear_usuario() {
    echo -e "${YELLOW}➕ Crear nuevo usuario:${RESET}"
    read -rp "👤 Usuario (será la contraseña): " usuario
    [ -z "$usuario" ] && { echo -e "${RED}⚠️ Usuario vacío.${RESET}"; return; }

    read -rp "⏳ Días de duración: " dias
    [[ ! "$dias" =~ ^[0-9]+$ ]] && { echo -e "${RED}⚠️ Días inválidos.${RESET}"; return; }

    exp=$(date -d "+$dias days" +"%d-%m-%Y")
    cp "$DB" "$DB.bak"
    echo "$usuario|$exp" >> "$DB"
    [ "$(cat $AUTO_CLEAN_FILE)" == "ON" ] && limpiar_vencidos_silencioso
    actualizar_config
    echo -e "${GREEN}✅ Usuario '$usuario' creado hasta $exp.${RESET}"
    mostrar_usuarios
}

# ❌ Remover usuario
remover_usuario() {
    mostrar_usuarios
    echo -e "${YELLOW}❌ Ingrese el usuario a eliminar:${RESET}"
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

# 🧹 Limpiar vencidos manual
limpiar_vencidos() {
    local now=$(date +%s)
    cp "$DB" "$DB.bak"
    awk -F'|' -v now="$now" '{
        cmd="date -d "$2" +%s"; cmd | getline t; close(cmd);
        if(t>now) print
    }' "$DB.bak" > "$DB"
    actualizar_config
    echo -e "${GREEN}🧹 Usuarios vencidos eliminados.${RESET}"
    mostrar_usuarios
}

# 🧹 Limpieza silenciosa
limpiar_vencidos_silencioso() {
    local now=$(date +%s)
    awk -F'|' -v now="$now" '{
        cmd="date -d "$2" +%s"; cmd | getline t; close(cmd);
        if(t>now) print
    }' "$DB" > "$DB.tmp" && mv "$DB.tmp" "$DB"
}

# 🔄 Alternar limpieza automática
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
    vencidos=$(awk -F'|' -v now=$(date +%s) '{cmd="date -d "$2" +%s"; cmd | getline t; close(cmd); if(t<now) c++} END{print c}' "$DB")
    estado_clean=$(cat "$AUTO_CLEAN_FILE")
    estado_text=$([ "$estado_clean" == "ON" ] && echo "${GREEN}[ON]${RESET}" || echo "${RED}[OFF]${RESET}")

    echo -e "\n${BLUE}
╔═══════════════════════════════════════════════════════╗
║             🧩 ZIVPN - PANEL DE USUARIOS UDP           ║
╠═══════════════════════════════════════════════════════╣
║ [1] ➕ Crear nuevo usuario (con expiración)            ║
║ [2] ❌ Remover usuario                                 ║
║ [3] 🔁 Renovar usuario                                 ║
║ [4] 📋 Ver usuarios actuales                           ║
║ [5] ▶️ Iniciar servicio                                ║
║ [6] 🔁 Reiniciar servicio                              ║
║ [7] ⏹️ Detener servicio                               ║
║ [8] 🧹 Limpiar usuarios vencidos   $estado_text         ║
║ [9] 🚪 Salir                                           ║
╚═══════════════════════════════════════════════════════╝${RESET}"
    [ "$vencidos" -gt 0 ] && echo -e "${YELLOW}⚠️ Hay $vencidos usuario(s) vencido(s).${RESET}"
    read -rp $'\n📤 Seleccione una opción [1-9]: ' opcion
    case $opcion in
        1) crear_usuario ;;
        2) remover_usuario ;;
        3) renovar_usuario ;;
        4) mostrar_usuarios; read -rp "🔙 Presione Enter para continuar..." ;;
        5) iniciar_servicio ;;
        6) reiniciar_servicio ;;
        7) detener_servicio ;;
        8)
            echo -e "\n${CYAN}¿Qué desea hacer?${RESET}"
            echo "1) 🧹 Limpiar usuarios vencidos manualmente"
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
done
