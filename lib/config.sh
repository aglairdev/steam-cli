#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
# ===============
# SETUP
# ===============

setup_config() {
    mkdir -p "$CONFIG_DIR/params" "$CONTROLLERS_DIR" "$GAMEPAD_TOOL_DIR"
    if [[ ! -f "$CONFIG_DIR/proton.conf" ]]; then
        cat > "$CONFIG_DIR/proton.conf" <<- EOC
# Proton padrao global (descomente e configure):
# PROTON_DEFAULT="/caminho/para/seu/proton"

# Proton por appid (descomente e configure):
# PROTON_413150="/caminho/para/outro/proton"
EOC
    fi
    source "$CONFIG_DIR/proton.conf"

    mkdir -p "$DEPS_DIR"
    if [[ ! -s "$DEPS_CONF" ]]; then
        cat > "$DEPS_CONF" <<-'EOC'
# mangohud
mangohud_arch="mangohud"
mangohud_fedora="mangohud"
mangohud_ubuntu="mangohud"

# gamemode
gamemode_arch="gamemode"
gamemode_fedora="gamemode"
gamemode_ubuntu="gamemode"

# deps 32-bit
deps32_arch="lib32-mesa lib32-openal lib32-libxi lib32-libxrandr lib32-libvorbis"
deps32_fedora="mesa-openal libXxf86vm.i686 libXi.i686"
deps32_ubuntu="libgl1-mesa-glx libopenal1 libxi6 libxrandr2"
EOC
    fi
    source "$DEPS_CONF"
}

# ===============
# PARÂMETROS
# ===============

load_params() {
    local file="$CONFIG_DIR/params/$1"
    [[ -f "$file" ]] || return
    local raw
    raw=$(cat "$file")
    local clean="" i char code
    for (( i=0; i<${#raw} && i<200; i++ )); do
        char="${raw:$i:1}"
        code=$(printf '%d' "'$char" 2>/dev/null || echo -1)
        (( code >= 32 && code != 127 )) && clean+="$char"
    done
    if [[ "$clean" != "$raw" ]]; then
        if [[ -n "$clean" ]]; then echo "$clean" > "$file"; else rm -f "$file"; fi
    fi
    echo "$clean"
}

save_params() {
    local file="$CONFIG_DIR/params/$1"
    if [[ -n "$2" ]]; then echo "$2" > "$file"
    elif [[ -f "$file" ]]; then rm "$file"; fi
}

edit_params() {
    local appid="$1" name="$2"
    local current_value=""
    current_value=$(load_params "$appid" 2>/dev/null) || true

    _current_display() {
        local val="$1" max
        max=$(( BOXW - 12 ))
        (( max < 8 )) && max=8
        [[ -z "$val" ]] && { echo "(vazio)"; return; }
        truncate_name "$val" "$max"
    }

    _draw_params_screen() {
        local sel="$1" allow_back="$2"
        render_logo
        box_top
        box_mid "Parâmetros"
        local name_display
        name_display=$(truncate_name "$name" $((BOXW - 6)))
        box_row "  ${name_display}" "  ${NEGRITO}${name_display}${NC}"
        local current_display
        current_display=$(_current_display "$current_value")
        box_row "  Atual: ${current_display}" "  Atual: ${CINZA}${current_display}${NC}"
        box_row_blank
        box_items "$sel" "Editar" "Resetar"
        box_bottom
        render_footer "$allow_back"
    }

    while true; do
        run_menu 2 _draw_params_screen true
        case "$MENU_RESULT" in
            BACK) return ;;
            0)
                ui_log_clear
                _draw_edit_input() {
                    local val="$1"
                    box_init
                    render_logo
                    box_top
                    box_mid "Editar Parâmetro"
                    local name_display
                    name_display=$(truncate_name "$name" $((BOXW - 6)))
                    box_row "  ${name_display}" "  ${NEGRITO}${name_display}${NC}"
                    local current_display
                    current_display=$(_current_display "$current_value")
                    box_row "  Atual: ${current_display}" "  Atual: ${CINZA}${current_display}${NC}"
                    box_row_blank
                    box_row_input "$val"
                    box_row_blank
                    box_row_hint
                    box_bottom
                }
                local new_value
                box_read_input _draw_edit_input
                new_value="$INPUT_RESULT"
                if [[ -n "$new_value" ]]; then
                    save_params "$appid" "$new_value"
                    current_value="$new_value"
                    $DEBUG && log_debug "[OK] param salvo: $new_value (appid $appid)" || true
                    status_box_start "Parâmetros"
                    status_box_add "${CHECK} parâmetro salvo"
                    auto_return_delay 1.2
                fi ;;
            1)
                save_params "$appid" ""
                current_value=""
                $DEBUG && log_debug "[OK] param limpo (appid $appid)" || true
                status_box_start "Parâmetros"
                status_box_add "${CHECK} parâmetro resetado"
                auto_return_delay 1.2 ;;
        esac
    done
}
