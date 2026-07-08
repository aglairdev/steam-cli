#
# © 2026 steam-cli ~ AGL ~ github.com/aglairdev
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
    local f="$CONFIG_DIR/params/$1"
    [[ -f "$f" ]] && cat "$f"
}

save_params() {
    local f="$CONFIG_DIR/params/$1"
    if [[ -n "$2" ]]; then echo "$2" > "$f"
    elif [[ -f "$f" ]]; then rm "$f"; fi
}

edit_params() {
    local a="$1" n="$2"
    local c=""
    c=$(load_params "$a" 2>/dev/null) || true

    while true; do
        clear
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-cli ${AGL}${NC}"
        box_top
        box_mid "Parâmetros"
        box_row "  ${n}" "  ${NEGRITO}${n}${NC}"
        local c_show="$c"
        [[ ${#c_show} -gt 36 ]] && c_show="${c_show:0:33}..."
        box_row "  Atual:${c_show:-(vazio)}" "  Atual:${CINZA}${c_show:-(vazio)}${NC}"
        box_row ""
        box_row "  [1]  Editar" "  [${AMARELO}1${NC}]  Editar"
        box_row "  [2]  Limpar" "  [${VERMELHO}2${NC}]  Limpar"
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        debug_flush
        echo ""
        read -p " > " opt
        case "$opt" in
            1)
                echo ""
                echo -e "  Atual:  ${CINZA}${c}${NC}\n"
                read -e -p " > " novo
                if [[ -n "$novo" ]]; then
                    save_params "$a" "$novo"
                    c="$novo"
                    $DEBUG && log_debug "OK    param salvo: $novo (appid $a)" || true
                    echo -e "  ${CHECK} parâmetro salvo"
                fi ; true ;;
            2)
                save_params "$a" ""
                c=""
                $DEBUG && log_debug "OK    param limpo (appid $a)" || true
                echo -e "  ${CHECK} parâmetro limpo" ; true ;;
            0) return ;;
            *) invalid_option ;;
        esac
    done
}

