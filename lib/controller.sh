#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
# ===============
# CONTROLE
# ===============

controller_status() {
    local a="$1" native="" mapping=""
    local f="$CONTROLLERS_DIR/$a"
    if [[ -f "$f" ]]; then
        native=$(grep '^NATIVE=' "$f" | cut -d'=' -f2- || true)
        mapping=$(grep '^MAPPING=' "$f" | cut -d'=' -f2- || true)
    fi
    $DEBUG && log_debug "CTRL   appid=$a native=$native mapping=${mapping:0:30}${mapping:+...}" || true
    if [[ -n "$native" ]] || [[ -n "$mapping" ]]; then
        echo "${native}|${mapping}"
    else
        echo "|"
    fi
}

set_controller_native() {
    local a="$1" v="$2" f="$CONTROLLERS_DIR/$a" mapping=""
    [[ -f "$f" ]] && mapping=$(grep '^MAPPING=' "$f" || true)
    { echo "NATIVE=${v}"; [[ -n "$mapping" ]] && echo "$mapping"; } > "$f" || true
    $DEBUG && log_debug "CTRL   native=$v salvo para appid $a" || true
}

set_controller_mapping() {
    local a="$1" v="$2" f="$CONTROLLERS_DIR/$a" native=""
    [[ -f "$f" ]] && native=$(grep '^NATIVE=' "$f" || true)
    { [[ -n "$native" ]] && echo "$native"; echo "MAPPING=${v}"; } > "$f" || true
    $DEBUG && log_debug "CTRL   mapping salvo para appid $a" || true
}

reset_controller_override() {
    rm -f "$CONTROLLERS_DIR/$1" || true
    $DEBUG && log_debug "CTRL   override resetado para appid $1" || true
}

apply_controller_mapping() {
    local a="$1" mapping=""
    if [[ -f "$CONTROLLERS_DIR/$a" ]]; then
        mapping=$(grep '^MAPPING=' "$CONTROLLERS_DIR/$a" | cut -d'=' -f2- || true)
    fi
    if [[ -z "$mapping" ]] && [[ -f "$CONTROLLER_GLOBAL_CONF" ]]; then
        mapping=$(cat "$CONTROLLER_GLOBAL_CONF" || true)
    fi
    if [[ -n "$mapping" ]] && is_valid_mapping "$mapping"; then
        export SDL_GAMECONTROLLERCONFIG="$mapping"
        $DEBUG && log_debug "OK    SDL_GAMECONTROLLERCONFIG aplicado (appid $a)" || true
    elif [[ -n "$mapping" ]]; then
        $DEBUG && log_debug "FALHA mapping inválido, ignorado (appid $a): ${mapping:0:40}..." || true
    fi
}

detect_controllers() {
    local devices=() name="" handlers=""
    [[ -f /proc/bus/input/devices ]] || { printf '%s\n' "${devices[@]}"; return; }
    while IFS= read -r line; do
        if [[ $line =~ ^N:\ Name=\"(.*)\" ]]; then
            name="${BASH_REMATCH[1]}"
        elif [[ $line =~ ^H:\ Handlers=(.*) ]]; then
            handlers="${BASH_REMATCH[1]}"
            if [[ $handlers =~ (js[0-9]+) ]]; then
                devices+=("${name}")
                $DEBUG && log_debug "CTRL   detectado: $name (handler: ${BASH_REMATCH[1]})" || true
            fi
            name=""; handlers=""
        fi
    done < /proc/bus/input/devices
    $DEBUG && log_debug "CTRL   ${#devices[@]} controles detectados" || true
    printf '%s\n' "${devices[@]}"
}

# ===============
# VALIDAÇÃO MAPPING
# ===============

is_valid_mapping() {
    local m="$1"
    [[ -z "$m" ]] && return 1
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[0-9a-fA-F]{8,40}, ]] || { $DEBUG && log_debug "FALHA mapping inválido (VID:PID): ${line:0:30}..."; return 1; }
        [[ "$line" =~ platform: ]] || { $DEBUG && log_debug "FALHA mapping inválido (sem platform:): ${line:0:30}..."; return 1; }
        [[ "$line" =~ ,[a-z]:b[0-9] ]] || [[ "$line" =~ ,[a-z]:h[0-9] ]] || { $DEBUG && log_debug "FALHA mapping inválido (sem botões): ${line:0:30}..."; return 1; }
    done <<< "$m"
    $DEBUG && log_debug "OK    mapping validado com sucesso" || true
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
    local json rv
    json=$(gamepad_tool_latest_release_json)
    [[ -z "$json" ]] && { GAMEPAD_TOOL_UPDATE_AVAILABLE=""; return; }
    rv=$(echo "$json" | grep -m1 '"tag_name"' | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\(.*\)".*/\1/')
    local iv
    iv=$(gamepad_tool_installed_version)
    if [[ -n "$rv" ]] && [[ "$rv" != "$iv" ]]; then
        GAMEPAD_TOOL_UPDATE_AVAILABLE="$rv"
    else
        GAMEPAD_TOOL_UPDATE_AVAILABLE=""
    fi
}

gamepad_tool_download() {
    echo ""
    echo -e "  ${CINZA}[INFO] consultando última versão ..${NC}"
    local json url rv
    json=$(gamepad_tool_latest_release_json)
    if [[ -z "$json" ]]; then
        echo -e "  ${XIS} falha ao consultar releases"
        $DEBUG && log_debug "FALHA gamepad-tool: sem resposta da API" || true
        return 1
    fi
    rv=$(echo "$json" | grep -m1 '"tag_name"' | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\(.*\)".*/\1/')
    url=$(echo "$json" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*linux-x86_64\.tar\.gz"' | head -1 | sed 's/.*"\(https:[^"]*\)"/\1/')
    if [[ -z "$url" ]]; then
        echo -e "  ${XIS} asset linux-x86_64 não encontrado na release"
        $DEBUG && log_debug "FALHA gamepad-tool: asset não encontrado" || true
        return 1
    fi

    mkdir -p "$GAMEPAD_TOOL_DIR"
    local tmp tmpdir
    tmp=$(mktemp)
    echo -e "  ${CINZA}[INFO] baixando gamepad-tool v${rv} ..${NC}"
    $DEBUG && log_debug "OK    gamepad-tool: baixando v${rv}" || true
    if ! curl -sL --connect-timeout 10 "$url" -o "$tmp"; then
        echo -e "  ${XIS} falha no download"
        $DEBUG && log_debug "FALHA gamepad-tool: download" || true
        rm -f "$tmp"
        return 1
    fi

    tmpdir=$(mktemp -d)
    if ! tar -xzf "$tmp" -C "$tmpdir" 2>/dev/null; then
        echo -e "  ${XIS} falha ao descompactar"
        $DEBUG && log_debug "FALHA gamepad-tool: extração" || true
        rm -f "$tmp"; rm -rf "$tmpdir"
        return 1
    fi
    rm -f "$tmp"

    local bin
    bin=$(find "$tmpdir" -maxdepth 2 -type f -name 'gamepad-tool' -print -quit 2>/dev/null)
    if [[ -z "$bin" ]]; then
        echo -e "  ${XIS} binário gamepad-tool não encontrado no pacote"
        $DEBUG && log_debug "FALHA gamepad-tool: binário ausente no tar.gz" || true
        rm -rf "$tmpdir"
        return 1
    fi

    rm -rf "$GAMEPAD_TOOL_DIR"
    mkdir -p "$GAMEPAD_TOOL_DIR"
    cp -r "$(dirname "$bin")/." "$GAMEPAD_TOOL_DIR/" 2>/dev/null || true
    chmod +x "$GAMEPAD_TOOL_BIN" 2>/dev/null || true
    echo "$rv" > "$GAMEPAD_TOOL_VERSION_FILE"
    rm -rf "$tmpdir"

    GAMEPAD_TOOL_UPDATE_AVAILABLE=""
    $DEBUG && log_debug "OK    gamepad-tool v${rv} instalado" || true
    echo -e "  ${CHECK} gamepad-tool v${rv} instalado"
    return 0
}

gamepad_tool_remove() {
    rm -rf "$GAMEPAD_TOOL_DIR" || true
    GAMEPAD_TOOL_UPDATE_AVAILABLE=""
    $DEBUG && log_debug "OK    gamepad-tool removido" || true
}

gamepad_tool_run_and_capture() {
    gamepad_tool_installed || return 1
    $DEBUG && log_debug "OK    abrindo gamepad-tool GUI (background)" || true
    "$GAMEPAD_TOOL_BIN" &>/dev/null &
    disown
    input_sdl_mapping
}


# ===============
# INPUT SDL_GAMECONTROLLERCONFIG
# ===============

input_sdl_mapping() {
    echo "" >&2
    echo -e "  ${CINZA}Cole aqui o valor de mapping string${NC}" >&2
    local novo_map
    while true; do
        read -e -p " > " novo_map
        if [[ -z "$novo_map" ]]; then
            echo "" >&2
            return 1
        fi
        if is_valid_mapping "$novo_map"; then
            echo "$novo_map"
            return 0
        fi
        echo -e "  ${VERMELHO}mapping inválido. tente novamente.${NC}" >&2
        echo "" >&2
    done
}

