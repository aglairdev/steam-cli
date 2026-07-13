#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
# ===============
# CONTROLE
# ===============

controller_status() {
    local appid="$1" native="" mapping=""
    local file="$CONTROLLERS_DIR/$appid"
    if [[ -f "$file" ]]; then
        native=$(grep '^NATIVE=' "$file" | cut -d'=' -f2- || true)
        mapping=$(grep '^MAPPING=' "$file" | cut -d'=' -f2- || true)
    fi
    if [[ -n "$native" ]] || [[ -n "$mapping" ]]; then
        echo "${native}|${mapping}"
    else
        echo "|"
    fi
}

set_controller_native() {
    local appid="$1" value="$2" file="$CONTROLLERS_DIR/$appid" mapping=""
    [[ -f "$file" ]] && mapping=$(grep '^MAPPING=' "$file" || true)
    { echo "NATIVE=${value}"; [[ -n "$mapping" ]] && echo "$mapping"; } > "$file" || true
    $DEBUG && log_debug "[OK] controle configurado: suporte nativo=$value (appid $appid)" || true
}

set_controller_mapping() {
    local appid="$1" value="$2" file="$CONTROLLERS_DIR/$appid" native=""
    [[ -f "$file" ]] && native=$(grep '^NATIVE=' "$file" || true)
    { [[ -n "$native" ]] && echo "$native"; echo "MAPPING=${value}"; } > "$file" || true
    $DEBUG && log_debug "[OK] controle configurado: mapeamento manual salvo (appid $appid)" || true
}

reset_controller_override() {
    rm -f "$CONTROLLERS_DIR/$1" || true
    $DEBUG && log_debug "[OK] controle resetado (appid $1)" || true
}

apply_controller_mapping() {
    local appid="$1" mapping=""
    if [[ -f "$CONTROLLERS_DIR/$appid" ]]; then
        mapping=$(grep '^MAPPING=' "$CONTROLLERS_DIR/$appid" | cut -d'=' -f2- || true)
    fi
    if [[ -z "$mapping" ]] && [[ -f "$CONTROLLER_GLOBAL_CONF" ]]; then
        mapping=$(cat "$CONTROLLER_GLOBAL_CONF" || true)
    fi
    if [[ -n "$mapping" ]] && is_valid_mapping "$mapping"; then
        export SDL_GAMECONTROLLERCONFIG="$mapping"
        $DEBUG && log_debug "[OK] SDL_GAMECONTROLLERCONFIG aplicado (appid $appid)" || true
    elif [[ -n "$mapping" ]]; then
        $DEBUG && log_debug "[ERROR] mapping inválido, ignorado (appid $appid): ${mapping:0:40}..." || true
    fi
}

detect_controllers() {
    local devices=()
    while IFS= read -r joystick; do
        if [[ -e "$joystick" ]]; then
            local name
            name=$(cat "/sys/class/input/$(basename "$joystick")/device/name" 2>/dev/null || echo "Desconhecido")
            devices+=("$name")
        fi
    done < <(ls /dev/input/js* 2>/dev/null)

    printf '%s\n' "${devices[@]}" | sort -u
}

# ===============
# VALIDAÇÃO MAPPING
# ===============

is_valid_mapping() {
    local mapping="$1"
    [[ -z "$mapping" ]] && return 1
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[0-9a-fA-F]{8,40}, ]] || { $DEBUG && log_debug "[ERROR] mapping inválido (VID:PID): ${line:0:30}..."; return 1; }
        [[ "$line" =~ platform: ]] || { $DEBUG && log_debug "[ERROR] mapping inválido (sem platform:): ${line:0:30}..."; return 1; }
        [[ "$line" =~ ,[a-z]:b[0-9] ]] || [[ "$line" =~ ,[a-z]:h[0-9] ]] || { $DEBUG && log_debug "[ERROR] mapping inválido (sem botões): ${line:0:30}..."; return 1; }
    done <<< "$mapping"
    $DEBUG && log_debug "[OK] mapping validado com sucesso" || true
    return 0
}

# ===============
# GAMEPAD-TOOL
# ===============

gamepad_tool_installed() {
    [[ -x "$GAMEPAD_TOOL_BIN" ]]
}

gamepad_tool_installed_version() {
    [[ -f "$GAMEPAD_TOOL_VERSION_FILE" ]] && cat "$GAMEPAD_TOOL_VERSION_FILE" || echo ""
}

gamepad_tool_latest_release_json() {
    curl -s --connect-timeout 5 "$GAMEPAD_TOOL_REPO_API" 2>/dev/null || true
}

gamepad_tool_check_update() {
    gamepad_tool_installed || { GAMEPAD_TOOL_UPDATE_AVAILABLE=""; return; }
    local release_json remote_version
    release_json=$(gamepad_tool_latest_release_json)
    [[ -z "$release_json" ]] && { GAMEPAD_TOOL_UPDATE_AVAILABLE=""; return; }
    remote_version=$(echo "$release_json" | grep -m1 '"tag_name"' | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\(.*\)".*/\1/')
    local installed_version
    installed_version=$(gamepad_tool_installed_version)
    if [[ -n "$remote_version" ]] && [[ "$remote_version" != "$installed_version" ]]; then
        GAMEPAD_TOOL_UPDATE_AVAILABLE="$remote_version"
    else
        GAMEPAD_TOOL_UPDATE_AVAILABLE=""
    fi
}

gamepad_tool_download() {
    loading_dots 2 "Consultando GitHub"

    local release_json download_url remote_version
    release_json=$(gamepad_tool_latest_release_json)
    if [[ -z "$release_json" ]]; then
        $DEBUG && log_debug "[ERROR] GitHub inacessível ao consultar releases do gamepad-tool" || true
        status_box_start "gamepad-tool"
        status_box_add "${XIS} falha ao consultar releases"
        sleep 1.5
        return 1
    fi

    remote_version=$(echo "$release_json" | grep -m1 '"tag_name"' | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\(.*\)".*/\1/')
    download_url=$(echo "$release_json" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*linux-x86_64\.tar\.gz"' | head -1 | sed 's/.*"\(https:[^"]*\)"/\1/')

    if [[ -z "$download_url" ]]; then
        status_box_start "gamepad-tool"
        status_box_add "${XIS} asset linux-x86_64 não encontrado"
        sleep 1.5
        return 1
    fi

    loading_dots 3 "baixando gamepad-tool v${remote_version}"

    mkdir -p "$GAMEPAD_TOOL_DIR"
    local tmp_archive tmp_dir
    tmp_archive=$(mktemp)

    if ! curl -sL --connect-timeout 10 "$download_url" -o "$tmp_archive"; then
        $DEBUG && log_debug "[ERROR] falha no download do gamepad-tool v${remote_version}" || true
        status_box_start "gamepad-tool"
        status_box_add "${XIS} falha no download"
        rm -f "$tmp_archive"
        sleep 1.5
        return 1
    fi

    tmp_dir=$(mktemp -d)
    tar -xzf "$tmp_archive" -C "$tmp_dir" 2>/dev/null
    rm -f "$tmp_archive"

    local bin
    bin=$(find "$tmp_dir" -maxdepth 2 -type f -name 'gamepad-tool' -print -quit 2>/dev/null)

    rm -rf "$GAMEPAD_TOOL_DIR"
    mkdir -p "$GAMEPAD_TOOL_DIR"
    cp -r "$(dirname "$bin")/." "$GAMEPAD_TOOL_DIR/" 2>/dev/null || true
    chmod +x "$GAMEPAD_TOOL_BIN" 2>/dev/null || true
    echo "$remote_version" > "$GAMEPAD_TOOL_VERSION_FILE"
    rm -rf "$tmp_dir"

    GAMEPAD_TOOL_UPDATE_AVAILABLE=""

    $DEBUG && log_debug "[OK] gamepad-tool v${remote_version} instalado" || true
    status_box_start "gamepad-tool"
    status_box_add "${CHECK} gamepad-tool v${remote_version} instalado"
    sleep 1.2
    return 0
}

gamepad_tool_remove() {
    rm -rf "$GAMEPAD_TOOL_DIR" || true
    GAMEPAD_TOOL_UPDATE_AVAILABLE=""
    $DEBUG && log_debug "[OK] gamepad-tool removido" || true
}

gamepad_tool_run_and_capture() {
    local current="${1:-}"
    gamepad_tool_installed || { INPUT_RESULT=""; return 1; }
    $DEBUG && log_debug "[OK] abrindo gamepad-tool GUI (background)" || true
    "$GAMEPAD_TOOL_BIN" &>/dev/null &
    disown
    input_sdl_mapping "$current"
}

# ===============
# INPUT SDL_GAMECONTROLLERCONFIG
# ===============

_sdl_current_display() {
    local val="$1" max
    max=$(( BOXW - 12 ))
    (( max < 8 )) && max=8
    [[ -z "$val" ]] && { echo "(vazio)"; return; }
    truncate_name "$val" "$max"
}

input_sdl_mapping() {
    local current="${1:-}"

    _draw_sdl_input() {
        local val="$1"
        box_init
        render_logo
        box_top
        box_mid "Configurar Mapeamento"
        local current_display
        current_display=$(_sdl_current_display "$current")
        box_row "  Mapeamento atual: ${current_display}" "  Mapeamento atual: ${CINZA}${current_display}${NC}"
        box_row_blank
        box_row_input "$val"
        box_row_blank
        box_row_hint
        box_bottom
    }

    box_read_input _draw_sdl_input
    local new_mapping="$INPUT_RESULT"

    if [[ -z "$new_mapping" ]]; then
        INPUT_RESULT=""
        return 1
    fi

    if is_valid_mapping "$new_mapping"; then
        INPUT_RESULT="$new_mapping"
        return 0
    fi

    status_box_start "Mapeamento Manual"
    status_box_add "${XIS} mapping inválido"
    auto_return_delay 1.2
    $DEBUG && log_debug "[ERROR] mapping manual inválido: ${new_mapping:0:30}..." || true
    INPUT_RESULT=""
    return 1
}
