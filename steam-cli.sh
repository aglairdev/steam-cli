#!/usr/bin/env bash
#
# steam-cli ~ biblioteca de jogos steam via terminal
# © 2026 steam-cli ~ AGL ~ github.com/aglairdev
# Licenca: MIT
#
# uso:  ./steam-cli.sh
#       ./steam-cli.sh -d     #debug
#       ./steam-cli.sh -v     #versao
#       ./steam-cli.sh -h     #ajuda
#

set -euo pipefail

VERSION="1.0.3"
AGL="ꕤ"

STEAM_HOME=""
STEAM_CMD="steam"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/steam-cli"
DEBUG=false
DEBUG_LOG=""

REPO_URL="https://raw.githubusercontent.com/aglairdev/steam-cli/main/steam-cli.sh"
TOOLS_APPIDS=(1070560 1493710 1628350 2180100 228980 4183110)

CONTROLE_DIR="$CONFIG_DIR/controle"
CONTROLLERS_DIR="$CONTROLE_DIR/jogos"
CONTROLLER_GLOBAL_CONF="$CONTROLE_DIR/global.conf"
GAMEPAD_TOOL_DIR="$CONTROLE_DIR/gamepad-tool"
GAMEPAD_TOOL_BIN="$GAMEPAD_TOOL_DIR/gamepad-tool"
GAMEPAD_TOOL_VERSION_FILE="$GAMEPAD_TOOL_DIR/.version"
GAMEPAD_TOOL_REPO_API="https://api.github.com/repos/General-Arcade/sdl2-gamepad-tool/releases/latest"
GAMEPAD_TOOL_UPDATE_AVAILABLE=""

VERDE='\033[38;2;120;170;120m'
VERMELHO='\033[38;2;190;100;100m'
AMARELO='\033[38;2;200;180;100m'
AZUL='\033[38;2;100;150;200m'
CINZA='\033[38;2;150;150;150m'
NEGRITO='\033[1m'
NC='\033[0m'

# ===============
# GLOBAIS
# ===============

LIBRARIES=()
GAMES=()
GAME_PID=""
CHECK="✔"
XIS="✘"
BOLINHO="${VERDE}●${NC}"

ICON_GAMEPAD=$'\uf11b'
ICON_KEYBOARD=$'\uf11c'
ICON_LINUX=$'\uf17c'
ICON_WINDOWS=$'\ue8e5'

log_debug() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "  ${CINZA}[DEBUG] ${msg}${NC}"
    echo "[$ts] $msg" >> "$DEBUG_LOG"
}

divider() {
    echo -e "${AZUL}-----------------------------------------------${NC}"
}

invalid_option() {
    echo -e "  ${VERMELHO}Comando nao disponivel${NC}"
    read -n1 -s -r
}

# ===============
# LARGURA DE EXIBICAO
# ===============

display_width() {
    local s="$1" w=0 i o
    for (( i=0; i<${#s}; i++ )); do
        o=$(printf '%d' "'${s:$i:1}" 2>/dev/null || echo 0)
        if (( o >= 0xF0000 )); then
            ((w+=2))
        else
            ((w++))
        fi
    done
    echo "$w"
}

truncate_name() {
    local name="$1" max="${2:-24}"
    local w
    w=$(display_width "$name")
    if (( w <= max )); then
        echo "$name"
    else
        local truncated="" cw=0 i
        for (( i=0; i<${#name}; i++ )); do
            local c="${name:$i:1}"
            local co
            co=$(printf '%d' "'$c" 2>/dev/null || echo 0)
            local cw_add=1
            (( co >= 0xF0000 )) && cw_add=2
            if (( cw + cw_add + 3 > max )); then
                break
            fi
            truncated+="$c"
            (( cw += cw_add ))
        done
        echo "${truncated}..."
    fi
}

pad_to_width() {
    local s="$1" target="$2"
    local w
    w=$(display_width "$s")
    local diff=$((target - w))
    (( diff < 0 )) && diff=0
    printf '%s%*s' "$s" "$diff" ""
}

# ===============
# BOX
# ===============

BOXW=44
box_top() {
    local d
    d=$(printf '─%.0s' $(seq 1 $BOXW))
    echo -e "${AZUL}┌${d}┐${NC}"
}
box_bottom() {
    local d
    d=$(printf '─%.0s' $(seq 1 $BOXW))
    echo -e "${AZUL}└${d}┘${NC}"
}
box_mid() {
    local titulo="$1" len
    len=$(display_width "$titulo")
    local total=$((BOXW - len - 2))
    local esq dir de dd
    esq=$((total / 2))
    dir=$((total - esq))
    de=$(printf '─%.0s' $(seq 1 $esq))
    dd=$(printf '─%.0s' $(seq 1 $dir))
    echo -e "${AZUL}├${de} ${titulo} ${dd}┤${NC}"
}
box_row() {
    local plano="$1" colorido="${2:-$1}"
    local pw
    pw=$(display_width "$plano")
    local pad=$((BOXW - pw))
    (( pad < 0 )) && pad=0
    local esp
    esp=$(printf '%*s' "$pad" "")
    echo -e "${AZUL}│${NC}${colorido}${esp}${AZUL}│${NC}"
}

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
}

# ===============
# DETECCAO STEAM
# ===============

detect_steam_installation() {
    if command -v steam &>/dev/null; then
        if [[ -d "$HOME/.steam/steam" ]]; then
            STEAM_HOME="$HOME/.steam/steam"
            STEAM_CMD="steam"
            $DEBUG && log_debug "OK  steam nativo encontrado: $STEAM_HOME" || true
            return 0
        fi
    fi

    if [[ -d "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam" ]]; then
        STEAM_HOME="$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"
        STEAM_CMD="flatpak run com.valvesoftware.Steam"
        $DEBUG && log_debug "OK  steam flatpak encontrado: $STEAM_HOME" || true
        return 0
    fi

    if [[ -d "$HOME/snap/steam/common/.steam/steam" ]]; then
        STEAM_HOME="$HOME/snap/steam/common/.steam/steam"
        STEAM_CMD="steam"
        $DEBUG && log_debug "OK  steam snap encontrado: $STEAM_HOME" || true
        return 0
    fi

    local steam_exe
    steam_exe=$(command -v steam 2>/dev/null || true)
    if [[ -n "$steam_exe" ]]; then
        local guess
        guess=$(dirname "$(dirname "$steam_exe")")/.steam/steam
        if [[ -d "$guess" ]]; then
            STEAM_HOME="$guess"
            STEAM_CMD="$steam_exe"
            $DEBUG && log_debug "OK  steam encontrado via PATH: $STEAM_HOME" || true
            return 0
        fi
    fi

    $DEBUG && log_debug "FALHA steam nao encontrado (nativo / flatpak / snap)" || true
    echo -e "  ${XIS} Steam nao encontrado (nativo / flatpak / snap)"
    exit 1
}

# ===============
# DETECCAO BIBLIOTECAS
# ===============

detect_libraries() {
    local vdf
    for vdf in "$STEAM_HOME/steamapps/libraryfolders.vdf" \
               "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"; do
        [[ -f "$vdf" ]] || continue
        while IFS= read -r line; do
            if [[ $line =~ ^[[:space:]]*\"path\"[[:space:]]*\"(.*)\" ]]; then
                local lib="${BASH_REMATCH[1]}"
                lib="${lib/#\~/$HOME}"
                LIBRARIES+=("$lib")
                $DEBUG && log_debug "OK  biblioteca: $lib" || true
            fi
        done < "$vdf"
        return 0
    done
    $DEBUG && log_debug "FALHA libraryfolders.vdf nao encontrado" || true
    echo -e "  ${XIS} libraryfolders.vdf nao encontrado" >&2
    exit 1
}

# ===============
# SCAN JOGOS
# ===============

scan_games() {
    $DEBUG && log_debug "SCAN  iniciando varredura de jogos" || true
    local temp=()
    for lib in "${LIBRARIES[@]}"; do
        local d="$lib/steamapps"
        [[ -d "$d" ]] || continue
        while IFS= read -r m; do
            [[ -f "$m" ]] || continue
            local a n i lp ts
            a=$(grep '"appid"' "$m" | sed 's/.*"appid"[[:space:]]*"\(.*\)"/\1/') || true
            n=$(grep '"name"' "$m" | sed 's/.*"name"[[:space:]]*"\(.*\)"/\1/') || true
            i=$(grep '"installdir"' "$m" | sed 's/.*"installdir"[[:space:]]*"\(.*\)"/\1/') || true
            lp=$(grep '"LastPlayed"' "$m" | sed 's/.*"LastPlayed"[[:space:]]*"\(.*\)"/\1/') || true
            ts=${lp:-$(stat --format='%Y' "$m" 2>/dev/null || echo 0)}
            temp+=("$ts|$a|$n|$i|$lib")
        done < <(find "$d" -maxdepth 1 -name 'appmanifest_*.acf' \
            -exec stat --format='%Y %n' {} \; 2>/dev/null | sort -n | cut -d' ' -f2-)
    done
    IFS=$'\n' temp=($(sort -t'|' -k1 -rn <<< "${temp[*]}"))
    unset IFS
    GAMES=()
    for g in "${temp[@]}"; do
        GAMES+=("${g#*|}")
    done
    $DEBUG && log_debug "SCAN  ${#GAMES[@]} jogos encontrados" || true
}

# ===============
# FILTRO
# ===============

filter_games() {
    local filtered=()
    for game in "${GAMES[@]}"; do
        IFS='|' read -r a n _ _ <<< "$game"
        local s=0
        for t in "${TOOLS_APPIDS[@]}"; do
            [[ "$a" == "$t" ]] && { s=1; break; }
        done
        [[ $s -eq 0 ]] || continue
        local nl="${n,,}"
        case "$nl" in
            *proton*) continue ;;
            *"steam linux runtime"*) continue ;;
            *steamworks*) continue ;;
        esac
        filtered+=("$game")
    done
    GAMES=("${filtered[@]}")
    $DEBUG && log_debug "FILTER ${#GAMES[@]} jogos apos filtro" || true
}

# ===============
# DETECCAO EXECUTAVEIS
# ===============

find_game_exe() {
    local i="$1" l="$2"
    local d="$l/steamapps/common/$i"
    [[ -d "$d" ]] || { $DEBUG && log_debug "EXE   diretorio nao encontrado: $d"; return 1; }
    local exes=()
    while IFS= read -r -d '' e; do
        local b=$(basename "$e"); b="${b,,}"
        case "$b" in
            uninstall*|unins*|*redist*|vcredist*|dxwebsetup*|dotnet*|*setup*) continue ;;
        esac
        exes+=("$e")
    done < <(find "$d" -maxdepth 2 -name '*.exe' -type f -print0 2>/dev/null)
    $DEBUG && log_debug "EXE   ${#exes[@]} executaveis .exe encontrados em $i" || true
    case ${#exes[@]} in
        0) $DEBUG && log_debug "FALHA nenhum .exe encontrado para $i"; return 1 ;;
        1) $DEBUG && log_debug "OK    exe selecionado: ${exes[0]}"; echo "${exes[0]}" ;;
        *)
            local dl="${i,,}"
            for e in "${exes[@]}"; do
                local en=$(basename "$e" .exe); en="${en,,}"
                if [[ "$en" == "$dl" ]]; then
                    $DEBUG && log_debug "OK    exe por nome: $e" || true
                    echo "$e"; return 0
                fi
            done
            $DEBUG && log_debug "OK    exe padrao: ${exes[0]}" || true
            echo "${exes[0]}" ;;
    esac
}

find_linux_exe() {
    local i="$1" l="$2"
    local d="$l/steamapps/common/$i"
    [[ -d "$d" ]] || { $DEBUG && log_debug "LIN   diretorio nao encontrado: $d"; return 1; }
    local il="${i,,}" elfs=()
    while IFS= read -r -d '' f; do
        file -b "$f" 2>/dev/null | grep -qi "ELF.*executable" && elfs+=("$f")
    done < <(find "$d" -maxdepth 2 -type f ! -name '*.*' -print0 2>/dev/null)
    $DEBUG && log_debug "LIN   ${#elfs[@]} ELF encontrados em $i" || true

    local candidate=""
    for f in "${elfs[@]}"; do
        local fn; fn=$(basename "$f"); fn="${fn,,}"
        if [[ "$fn" == "$il" ]]; then
            candidate="$f"; break
        fi
    done
    if [[ -z "$candidate" ]]; then
        for f in "${elfs[@]}"; do
            local fn; fn=$(basename "$f"); fn="${fn,,}"
            if [[ "$fn" == *launcher* ]]; then
                candidate="$f"; break
            fi
        done
    fi
    if [[ -z "$candidate" ]]; then
        for f in "${elfs[@]}"; do
            if [[ -x "$f" ]]; then
                candidate="$f"; break
            fi
        done
    fi
    [[ -z "$candidate" ]] && candidate="${elfs[0]:-}"
    if [[ -n "$candidate" ]]; then
        $DEBUG && log_debug "OK    exe linux: $candidate" || true
        echo "$candidate"; return 0
    fi

    for s in "start.sh" "launch.sh" "run.sh" "game.sh" "${il}.sh"; do
        if [[ -f "$d/$s" ]]; then
            $DEBUG && log_debug "OK    shell script: $d/$s" || true
            echo "$d/$s"; return 0
        fi
    done
    $DEBUG && log_debug "FALHA nenhum executavel linux para $i" || true
    return 1
}

get_platform_icon() {
    local i="$1" l="$2"
    local d="$l/steamapps/common/$i"
    [[ -d "$d" ]] || { echo "$ICON_WINDOWS"; return; }
    while IFS= read -r -d '' f; do
        file -b "$f" 2>/dev/null | grep -qi "ELF.*executable" && { echo "$ICON_LINUX"; return; }
    done < <(find "$d" -maxdepth 2 -type f ! -name '*.*' -print0 2>/dev/null)
    echo "$ICON_WINDOWS"
}

# ===============
# RUNTIME
# ===============

find_runtime() {
    for l in "${LIBRARIES[@]}"; do
        for r in "SteamLinuxRuntime_sniper" "SteamLinuxRuntime_4" "SteamLinuxRuntime"; do
            local b="$l/steamapps/common/$r/run"
            if [[ -x "$b" ]]; then
                $DEBUG && log_debug "OK    runtime: $b" || true
                echo "$b"; return 0
            fi
        done
    done
    $DEBUG && log_debug "FALHA runtime nao encontrado" || true
    return 1
}

# ===============
# PROTON
# ===============

get_proton() {
    local a="$1" v="PROTON_${a}"
    if [[ -n "${!v:-}" ]]; then
        $DEBUG && log_debug "OK    proton por variavel: ${!v}" || true
        echo "${!v}"; return
    fi
    if [[ -n "${PROTON_DEFAULT:-}" ]] && [[ -f "$PROTON_DEFAULT" ]]; then
        $DEBUG && log_debug "OK    proton default: $PROTON_DEFAULT" || true
        echo "$PROTON_DEFAULT"; return
    fi
    for l in "${LIBRARIES[@]}"; do
        local pd="$l/steamapps/common"
        [[ -d "$pd" ]] || continue
        while IFS= read -r -d '' p; do
            if [[ -x "$p" ]]; then
                $DEBUG && log_debug "OK    proton encontrado: $p" || true
                echo "$p"; return
            fi
        done < <(find "$pd" -maxdepth 3 -name 'proton' -type f -print0 2>/dev/null)
    done
    $DEBUG && log_debug "FALHA proton nao encontrado para appid $a" || true
    echo ""
}

get_proton_label() {
    local p
    p=$(get_proton "$1")
    [[ -z "$p" ]] && { echo "Proton"; return; }
    basename "$(dirname "$p")"
}

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
        $DEBUG && log_debug "FALHA mapping invalido, ignorado (appid $a): ${mapping:0:40}..." || true
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
# VALIDACAO MAPPING
# ===============

is_valid_mapping() {
    local m="$1"
    [[ -z "$m" ]] && return 1
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[0-9a-fA-F]{8,40}, ]] || { $DEBUG && log_debug "FALHA mapping invalido (VID:PID): ${line:0:30}..."; return 1; }
        [[ "$line" =~ platform: ]] || { $DEBUG && log_debug "FALHA mapping invalido (sem platform:): ${line:0:30}..."; return 1; }
        [[ "$line" =~ ,[a-z]:b[0-9] ]] || [[ "$line" =~ ,[a-z]:h[0-9] ]] || { $DEBUG && log_debug "FALHA mapping invalido (sem botoes): ${line:0:30}..."; return 1; }
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
    echo -e "  ${CINZA}[INFO] consultando ultima versao ..${NC}"
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
        echo -e "  ${XIS} asset linux-x86_64 nao encontrado na release"
        $DEBUG && log_debug "FALHA gamepad-tool: asset nao encontrado" || true
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
        $DEBUG && log_debug "FALHA gamepad-tool: extracao" || true
        rm -f "$tmp"; rm -rf "$tmpdir"
        return 1
    fi
    rm -f "$tmp"

    local bin
    bin=$(find "$tmpdir" -maxdepth 2 -type f -name 'gamepad-tool' -print -quit 2>/dev/null)
    if [[ -z "$bin" ]]; then
        echo -e "  ${XIS} binario gamepad-tool nao encontrado no pacote"
        $DEBUG && log_debug "FALHA gamepad-tool: binario ausente no tar.gz" || true
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
# PARAMS
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

# ===============
# INPUT SDL_GAMECONTROLLERCONFIG
# ===============

input_sdl_mapping() {
    echo ""
    echo -e "  ${CINZA}cole aqui o mapping string${NC}"
    echo -e "  ${CINZA}github.com/General-Arcade/sdl2-gamepad-tool/releases${NC}"
    echo ""
    local novo_map
    while true; do
        read -e -p " > " novo_map
        if [[ -z "$novo_map" ]]; then
            echo ""
            return 1
        fi
        if is_valid_mapping "$novo_map"; then
            echo "$novo_map"
            return 0
        fi
        echo -e "  ${VERMELHO}mapping invalido. tente novamente.${NC}"
        echo ""
    done
}

# ===============
# LANCAMENTO NATIVO
# ===============

launch_native() {
    local a="$1" n="$2" e="$3"
    local d
    d=$(dirname "$e")
    local p
    p=$(load_params "$a") || true
    apply_controller_mapping "$a"

    $DEBUG && log_debug "LAUNCH tentativa nativa: $n (appid $a)" || true

    local altered=false
    while IFS= read -r -d '' f; do
        if [[ ! -x "$f" ]]; then
            chmod +x "$f" 2>/dev/null || true
            altered=true
        fi
    done < <(find "$d" -maxdepth 2 -type f \( -executable -o -name '*launcher*' \) -print0 2>/dev/null)
    while IFS= read -r -d '' f; do
        if file -b "$f" 2>/dev/null | grep -qi "ELF.*executable"; then
            if [[ ! -x "$f" ]]; then
                chmod +x "$f" 2>/dev/null || true
                altered=true
            fi
        fi
    done < <(find "$d" -maxdepth 2 -type f ! -name '*.*' -print0 2>/dev/null)
    local libdir="$d/lib"
    if [[ -d "$libdir" ]] && [[ -n "$(find "$libdir" -type f ! -perm -o+w -print -quit 2>/dev/null)" ]]; then
        find "$libdir" -type f ! -perm -o+w -exec chmod +wx {} \; 2>/dev/null || true
        altered=true
    fi
    $altered && echo -e "  ${CHECK} permissoes corrigidas"

    [[ -z "$e" ]] && {
        echo -e "  ${XIS} ${n} nao tem binario nativo"
        $DEBUG && log_debug "FALHA nenhum binario nativo para $n" || true
        ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}" || true
        return
    }

    local b
    b=$(basename "$e")
    export SteamAppId="$a" SteamGameId="$a"

    if $DEBUG; then
        log_debug "OK    binario: $e"
        if [[ -z "$p" ]]; then
            log_debug "OK    params: nenhum"
        else
            log_debug "OK    params: $p"
        fi
    fi

    $DEBUG && log_debug "LAUNCH tentativa direta: ./$b" || true
    (cd "$d"; if $DEBUG; then "./$b" $p; else "./$b" $p &>/dev/null; fi) &
    GAME_PID=$!; sleep 1

    if kill -0 "$GAME_PID" 2>/dev/null; then
        echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
        echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
        $DEBUG && log_debug "OK    iniciado (pid: $GAME_PID)" || true
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
        $DEBUG && log_debug "OK    fechado (exit: $?)" || true
        GAME_PID=""; return
    fi
    wait "$GAME_PID" 2>/dev/null || true
    $DEBUG && log_debug "FALHA tentativa direta falhou" || true

    local rt
    rt=$(find_runtime) || true
    if [[ -n "$rt" ]]; then
        $DEBUG && log_debug "LAUNCH tentativa via runtime: $rt" || true
        (cd "$d"; if $DEBUG; then "$rt" -- "./$b" $p; else "$rt" -- "./$b" $p &>/dev/null; fi) &
        GAME_PID=$!; sleep 1
        if kill -0 "$GAME_PID" 2>/dev/null; then
            echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
            echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
            $DEBUG && log_debug "OK    iniciado via runtime (pid: $GAME_PID)" || true
            wait "$GAME_PID" 2>/dev/null || true
            echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
            $DEBUG && log_debug "OK    fechado via runtime (exit: $?)" || true
            GAME_PID=""; return
        fi
        wait "$GAME_PID" 2>/dev/null || true
        $DEBUG && log_debug "FALHA tentativa via runtime falhou" || true
    fi

    local rest=()
    while IFS= read -r -d '' f; do
        file -b "$f" 2>/dev/null | grep -qi "ELF.*executable" && [[ "$f" != "$e" ]] && rest+=("$f")
    done < <(find "$d" -maxdepth 2 -type f ! -name '*.*' -print0 2>/dev/null)

    if [[ ${#rest[@]} -gt 0 ]]; then
        local s="${rest[0]}" sn
        sn=$(basename "$s")
        $DEBUG && log_debug "LAUNCH tentativa alternativo: $sn" || true
        if [[ -n "$rt" ]]; then
            (cd "$d"; if $DEBUG; then "$rt" -- "./$sn" $p; else "$rt" -- "./$sn" $p &>/dev/null; fi) &
        else
            (cd "$d"; if $DEBUG; then "./$sn" $p; else "./$sn" $p &>/dev/null; fi) &
        fi
        GAME_PID=$!; sleep 1
        if kill -0 "$GAME_PID" 2>/dev/null; then
            echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
            echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
            $DEBUG && log_debug "OK    iniciado via alternativo (pid: $GAME_PID)" || true
            wait "$GAME_PID" 2>/dev/null || true
            echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
            $DEBUG && log_debug "OK    fechado via alternativo (exit: $?)" || true
            GAME_PID=""; return
        fi
        wait "$GAME_PID" 2>/dev/null || true
        $DEBUG && log_debug "FALHA tentativa alternativo falhou" || true
    fi

    echo -e "  ${XIS} ${NEGRITO}${n}${NC} nao iniciou"
    $DEBUG && log_debug "FALHA $n nao iniciou (todas as tentativas falharam)" || true
    ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}" || true
    GAME_PID=""
}

# ===============
# LANCAMENTO PROTON
# ===============

launch_proton() {
    local a="$1" n="$2" e="$3"
    local d
    d=$(dirname "$e")
    local p
    p=$(load_params "$a") || true
    apply_controller_mapping "$a"
    local pl
    pl=$(get_proton_label "$a")

    $DEBUG && log_debug "LAUNCH tentativa proton: $n (appid $a)" || true

    [[ -z "$e" ]] && {
        echo -e "  ${XIS} .exe nao encontrado para ${NEGRITO}${n}${NC}"
        $DEBUG && log_debug "FALHA .exe nao encontrado para ${n}" || true
        ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}" || true
        return
    }

    local pr
    pr=$(get_proton "$a")

    [[ -z "$pr" ]] || [[ ! -f "$pr" ]] && {
        echo -e "  ${XIS} Proton nao encontrado para ${NEGRITO}${n}${NC}"
        echo -e "  ${CINZA}[INFO] configure ${CONFIG_DIR}/proton.conf${NC}"
        $DEBUG && log_debug "FALHA Proton nao encontrado para ${a}" || true
        read -p "  Enter para voltar..."; return
    }

    local cd="${d%%/common/$i}/compatdata/$a"

    if $DEBUG; then
        log_debug "OK    .exe: $e"
        log_debug "OK    proton: $pr"
        log_debug "OK    compatdata: $cd"
        log_debug "OK    STEAM_HOME: $STEAM_HOME"
    fi

    mkdir -p "$cd"
    export STEAM_COMPAT_DATA_PATH="$cd"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_HOME"
    export SteamAppId="$a" SteamGameId="$a"

    echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (${pl})"
    $DEBUG && log_debug "LAUNCH executando proton: $pr run $e" || true

    if $DEBUG; then "$pr" run "$e" $p &
    else "$pr" run "$e" $p &>/dev/null & fi
    GAME_PID=$!; sleep 1

    if kill -0 "$GAME_PID" 2>/dev/null; then
        echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
        $DEBUG && log_debug "OK    iniciado via proton (pid: $GAME_PID)" || true
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
        $DEBUG && log_debug "OK    fechado via proton (exit: $?)" || true
    else
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${XIS} ${NEGRITO}${n}${NC} nao iniciou via Proton"
        $DEBUG && log_debug "FALHA ${n} nao iniciou via Proton" || true
        ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}" || true
    fi
    GAME_PID=""
}

# ===============
# STEAM
# ===============

prompt_exit_steam() {
    pgrep -x steam >/dev/null 2>&1 || return
    read -p "  Sair da steam? (s/N): " resp
    case "${resp,,}" in
        s|sim)
            echo -e "  ${CINZA}[INFO] finalizando steam ..${NC}"
            $STEAM_CMD -shutdown 2>/dev/null
            sleep 1; wait 2>/dev/null
            echo -e "  ${CHECK} steam finalizado"; exit 0 ;;
    esac
}

cleanup() {
    if [[ -n "$GAME_PID" ]] && kill -0 "$GAME_PID" 2>/dev/null; then
        echo ""
        echo -e "  ${AMARELO}[WARN]${NC} encerrando jogo (pid: ${GAME_PID})"
        kill -- "-$GAME_PID" 2>/dev/null || true
        wait "$GAME_PID" 2>/dev/null || true
    fi
    if $DEBUG && [[ -n "$DEBUG_LOG" ]]; then
        local ts
        ts=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$ts] === FIM DA SESSAO ===" >> "$DEBUG_LOG"
        echo "--" >> "$DEBUG_LOG"
    fi
}
trap cleanup EXIT INT TERM

# ===============
# PARAMETROS
# ===============

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
        box_mid "Parametros"
        box_row "  ${n}" "  ${NEGRITO}${n}${NC}"
        box_row "  Atual:${c:-(vazio)}" "  Atual:${CINZA}${c:-(vazio)}${NC}"
        box_row ""
        box_row "  [1]  Editar" "  [${AMARELO}1${NC}]  Editar"
        box_row "  [2]  Limpar" "  [${VERMELHO}2${NC}]  Limpar"
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        echo ""
        read -p " > " opt
        case "$opt" in
            1)
                echo ""
                read -e -p " > " novo
                if [[ -n "$novo" ]]; then
                    save_params "$a" "$novo"
                    c="$novo"
                    $DEBUG && log_debug "OK    param salvo: $novo (appid $a)" || true
                    echo -e "  ${CHECK} parametro salvo"
                fi ; true ;;
            2)
                save_params "$a" ""
                c=""
                $DEBUG && log_debug "OK    param limpo (appid $a)" || true
                echo -e "  ${CHECK} parametro limpo" ; true ;;
            0) return ;;
            *) invalid_option ;;
        esac
    done
}

# ===============
# UPDATE
# ===============

check_update() {
    [[ -z "$REPO_URL" ]] && return
    local rv
    rv=$(curl -s --connect-timeout 3 "$REPO_URL" | grep '^VERSION=' | head -1 | cut -d'"' -f2) || true
    [[ -z "$rv" ]] || [[ "$rv" == "$VERSION" ]] && return

    echo ""
    echo -e "  ${AGL} nova versao: ${VERDE}v${rv}${NC} (atual: ${VERMELHO}v${VERSION}${NC})"
    divider
    sleep 1
    read -p "  Atualizar? (s/N): " resp
    case "${resp,,}" in
        s|sim)
            $DEBUG && log_debug "OK    atualizando v$VERSION -> v$rv" || true
            echo -e "  ${CINZA}[INFO] baixando v${rv} ..${NC}"
            local tmp
            tmp=$(mktemp)
            if curl -sL --connect-timeout 10 "$REPO_URL" -o "$tmp"; then
                chmod +x "$tmp"
                cat "$tmp" > "$0"
                rm -f "$tmp"
                echo -e "  ${CHECK} atualizado. Reiniciando .."
                exec "$0" "$@"
            else
                echo -e "  ${XIS} falha no download"
                rm -f "$tmp"
            fi ; true ;;
    esac
    echo ""
}

# ===============
# BAIXAR JOGOS
# ===============

baixar_jogos() {
    clear
    echo ""
    local debug_tag=""
    $DEBUG && debug_tag="[DEBUG] " || true
    echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-cli ${AGL}${NC}"
    divider
    echo -e "  ${VERDE}Manifest${NC} ~ baixar manifests Steam"
    echo ""
    if command -v manifest &>/dev/null; then
        $DEBUG && log_debug "OK    Manifest: baixando jogos" || true
        echo -e "  ${CINZA}github.com/aglairdev/Manifest${NC}"
        divider
        manifest
        echo ""
        echo "[scan] atualizando ..."
        scan_games
        filter_games
        echo -e "  ${CHECK} lista atualizada"
    else
        $DEBUG && log_debug "FALHA Manifest nao instalado" || true
        echo -e "  ${AMARELO}[INFO]${NC} Manifest nao encontrado"
        echo -e "  ${CINZA}github.com/aglairdev/Manifest${NC}"
    fi
    read -p "  Enter para voltar"
}

# ===============
# MENU DO JOGO
# ===============

show_game_menu() {
    local game="$1"
    IFS='|' read -r a n i l <<< "$game"
    $DEBUG && log_debug "OK    menu: $n (appid $a)" || true

    local linux_exe="" win_exe="" hn=false hp=false
    linux_exe=$(find_linux_exe "$i" "$l" 2>/dev/null) || true
    if [[ -n "$linux_exe" ]]; then
        hn=true
    else
        win_exe=$(find_game_exe "$i" "$l" 2>/dev/null) || true
        get_proton "$a" &>/dev/null && hp=true || hp=false
    fi

    while true; do
        clear
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-cli ${AGL}${NC}"
        box_top
        box_mid "$n"
        if [[ $hn == true ]] || [[ $hp == true ]]; then
            box_row "  [1]  Jogar" "  [${VERDE}1${NC}]  Jogar"
        else
            box_row "  [!]  Jogar (Proton nao configurado)" "  [${VERMELHO}!${NC}]  Jogar (Proton nao configurado)"
        fi
        box_row "  [2]  Mapear controle" "  [${AMARELO}2${NC}]  Mapear controle"
        box_row "  [3]  Parametros" "  [${AMARELO}3${NC}]  Parametros"
        box_row "  [4]  Excluir" "  [${VERMELHO}4${NC}]  Excluir"
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        echo ""
        read -p " > " c

        if [[ "$c" == "1" ]]; then
            if [[ $hn == true ]]; then
                launch_native "$a" "$n" "$linux_exe"
            elif [[ $hp == true ]]; then
                launch_proton "$a" "$n" "$win_exe"
            fi
            read -p "  Enter para continuar..."
        elif [[ "$c" == "2" ]]; then
            show_game_controller_menu "$a" "$n"
        elif [[ "$c" == "3" ]]; then
            edit_params "$a" "$n"
        elif [[ "$c" == "4" ]]; then
            echo ""
            echo -e "  Excluir ${NEGRITO}${n}${NC}? (s/N)"
            read -p " > " resp
            case "${resp,,}" in
                s|sim)
                    $DEBUG && log_debug "OK    removendo jogo: $n (appid $a)" || true
                    echo -e "  ${CINZA}[INFO] removendo ${n} ..${NC}"
                    rm -rf "$l/steamapps/common/$i" 2>/dev/null || true
                    rm -f "$l/steamapps/appmanifest_${a}.acf" 2>/dev/null || true
                    rm -rf "$l/steamapps/compatdata/$a" 2>/dev/null || true
                    echo -e "  ${CHECK} ${n} removido"
                    local ng=()
                    for g in "${GAMES[@]}"; do
                        IFS='|' read -r ga _ _ _ <<< "$g"
                        [[ "$ga" != "$a" ]] && ng+=("$g")
                    done
                    GAMES=("${ng[@]}"); sleep 1; return ; true ;;
            esac
        elif [[ "$c" == "0" ]]; then
            return
        else
            invalid_option
        fi
    done
}

# ===============
# MENU DE MAPEAMENTO (POR JOGO)
# ===============

show_game_controller_menu() {
    local a="$1" n="$2"
    while true; do
        local native="" mapping="" status_label status_icon
        IFS='|' read -r native mapping <<< "$(controller_status "$a")"
        if [[ "$native" == "yes" ]]; then
            status_label="suporte nativo"; status_icon="$ICON_GAMEPAD"
        elif [[ -n "$mapping" ]] && is_valid_mapping "$mapping"; then
            status_label="config manual"; status_icon="$ICON_GAMEPAD"
        else
            status_label="teclado"; status_icon="$ICON_KEYBOARD"
        fi

        clear
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-cli ${AGL}${NC}"
        box_top
        box_mid "Mapear"
        box_row "  ${n}" "  ${NEGRITO}${n}${NC}"
        box_row "  Status: ${status_icon}" "  Status: ${NEGRITO}${status_icon}${NC}"
        box_row ""
        if [[ "$native" == "yes" ]]; then
            box_row "  [1]  Desmarcar suporte nativo" "  [${VERMELHO}1${NC}]  Desmarcar suporte nativo"
        else
            box_row "  [1]  Marcar suporte nativo" "  [${VERDE}1${NC}]  Marcar suporte nativo"
        fi
        box_row "  [2]  Configurar mapeamento" "  [${AMARELO}2${NC}]  Configurar mapeamento"
        box_row "  [3]  Resetar" "  [${VERMELHO}3${NC}]  Resetar"
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        echo ""
        read -p " > " c
        case "$c" in
            1)
                if [[ "$native" == "yes" ]]; then
                    set_controller_native "$a" "no" || true
                    $DEBUG && log_debug "OK    suporte nativo desmarcado (appid $a)" || true
                    echo -e "  ${CHECK} suporte nativo desmarcado"
                else
                    set_controller_native "$a" "yes" || true
                    $DEBUG && log_debug "OK    suporte nativo marcado (appid $a)" || true
                    echo -e "  ${CHECK} suporte nativo marcado"
                fi
                sleep 1 ; true ;;
            2)
                $DEBUG && log_debug "OK    iniciando configuracao de mapeamento (appid $a)" || true
                local novo_map=""
                if gamepad_tool_installed; then
                    novo_map=$(gamepad_tool_run_and_capture) || true
                else
                    novo_map=$(input_sdl_mapping) || true
                fi
                if [[ -n "$novo_map" ]]; then
                    set_controller_mapping "$a" "$novo_map" || true
                    echo -e "  ${CHECK} mapeamento salvo"
                    sleep 0.5
                    continue
                fi
                sleep 1 ; true ;;
            3)
                reset_controller_override "$a" || true
                echo -e "  ${CHECK} configuracoes resetadas"
                sleep 1 ; true ;;
            0) return ;;
            *) invalid_option ;;
        esac
    done
}

# ===============
# MENU DE CONTROLES (GLOBAL)
# ===============

show_controller_device_menu() {
    local dname="$1"
    while true; do
        local global_map=""
        [[ -f "$CONTROLLER_GLOBAL_CONF" ]] && global_map=$(cat "$CONTROLLER_GLOBAL_CONF" || true)

        local tool_installed=false
        gamepad_tool_installed && tool_installed=true

        local opt_configure=1 opt_update=0 opt_reset opt_remove=0 next=2
        if $tool_installed && [[ -n "$GAMEPAD_TOOL_UPDATE_AVAILABLE" ]]; then
            opt_update=$next; ((next++))
        fi
        opt_reset=$next; ((next++))
        if $tool_installed; then
            opt_remove=$next; ((next++))
        fi

        clear
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-cli ${AGL}${NC}"
        box_top
        box_mid "$dname"
        if [[ -n "$global_map" ]] && is_valid_mapping "$global_map"; then
            box_row "  Status: mapeamento ativo"
        else
            box_row "  Status: sem mapeamento"
        fi
        box_row ""
        if $tool_installed; then
            box_row "  [${opt_configure}]  Configurar mapeamento geral" "  [${AMARELO}${opt_configure}${NC}]  Configurar mapeamento geral"
        else
            box_row "  [${opt_configure}]  Baixar gamepad-tool" "  [${AMARELO}${opt_configure}${NC}]  Baixar gamepad-tool"
        fi
        if (( opt_update > 0 )); then
            box_row "  [${opt_update}]  Atualizacao disponivel (v${GAMEPAD_TOOL_UPDATE_AVAILABLE})" "  [${AMARELO}${opt_update}${NC}]  Atualizacao disponivel (v${GAMEPAD_TOOL_UPDATE_AVAILABLE})"
        fi
        box_row "  [${opt_reset}]  Resetar" "  [${VERMELHO}${opt_reset}${NC}]  Resetar"
        if (( opt_remove > 0 )); then
            box_row "  [${opt_remove}]  Remover gamepad-tool" "  [${VERMELHO}${opt_remove}${NC}]  Remover gamepad-tool"
        fi
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        echo ""
        read -p " > " c

        if [[ "$c" == "0" ]]; then
            return
        elif [[ "$c" == "$opt_configure" ]]; then
            if $tool_installed; then
                $DEBUG && log_debug "OK    configurando mapeamento geral" || true
                local novo_map=""
                novo_map=$(gamepad_tool_run_and_capture) || true
                if [[ -n "$novo_map" ]]; then
                    echo "$novo_map" > "$CONTROLLER_GLOBAL_CONF" || true
                    $DEBUG && log_debug "OK    mapeamento geral salvo" || true
                    echo -e "  ${CHECK} mapeamento geral salvo"
                fi
            else
                gamepad_tool_download || true
            fi
            sleep 1
        elif (( opt_update > 0 )) && [[ "$c" == "$opt_update" ]]; then
            gamepad_tool_download || true
            sleep 1
        elif [[ "$c" == "$opt_reset" ]]; then
            rm -f "$CONTROLLER_GLOBAL_CONF" || true
            $DEBUG && log_debug "OK    mapeamento geral resetado" || true
            echo -e "  ${CHECK} mapeamento geral resetado"
            sleep 1
        elif (( opt_remove > 0 )) && [[ "$c" == "$opt_remove" ]]; then
            echo ""
            echo -e "  Remover gamepad-tool? (s/N)"
            read -p " > " resp
            case "${resp,,}" in
                s|sim)
                    echo -e "  ${CINZA}[INFO] removendo gamepad-tool ..${NC}"
                    gamepad_tool_remove
                    echo -e "  ${CHECK} gamepad-tool removido"
                    sleep 1 ;;
            esac
        else
            invalid_option
        fi
    done
}

show_controllers_menu() {
    local devices=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && devices+=("$line")
    done < <(detect_controllers)

    gamepad_tool_check_update

    while true; do
        clear
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-cli ${AGL}${NC}"
        box_top
        box_mid "Controles"
        if [[ ${#devices[@]} -eq 0 ]]; then
            box_row "  nenhum controle detectado"
        else
            local idx=1
            for dname in "${devices[@]}"; do
                box_row "  [${idx}]  ${dname}" "  [${AMARELO}${idx}${NC}]  ${dname}"
                ((idx++))
            done
        fi
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        echo ""
        read -p " > " c

        case "$c" in
            0) return ;;
            [1-9]|[1-9][0-9])
                if (( ${#devices[@]} > 0 && c >= 1 && c <= ${#devices[@]} )); then
                    show_controller_device_menu "${devices[$((c-1))]}"
                else
                    invalid_option
                fi ; true ;;
            *) invalid_option ;;
        esac
    done
}

# ===============
# MENU PRINCIPAL
# ===============

show_main_menu() {
    local first=true
    while true; do
        clear
        if [[ $first == true ]]; then
            check_update "$@"
            first=false
        fi
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-cli ${AGL}${NC}"

        if [[ ${#GAMES[@]} -eq 0 ]]; then
            box_top
            box_mid "Loja"
            box_row "  [B]  Baixar jogos" "  [${VERDE}B${NC}]  Baixar jogos"
            box_mid "Sair"
            box_row "  [0]  Fechar" "  [${VERMELHO}0${NC}]  Fechar"
            box_bottom
            read -p " > " c
            case "$c" in
                0) $DEBUG && log_debug "OK    fechando steam-cli"; prompt_exit_steam; exit 0 ; true ;;
                [bB]) $DEBUG && log_debug "OK    acessando baixar jogos"; baixar_jogos; scan_games; filter_games ; true ;;
                *) invalid_option ;;
            esac
        else
            box_top
            box_mid "Loja"
            box_row "  [B]  Baixar jogos" "  [${VERDE}B${NC}]  Baixar jogos"
            box_mid "Biblioteca"
            local idx=1 a n i l native mapping icon plat display_n padded
            for game in "${GAMES[@]}"; do
                IFS='|' read -r a n i l <<< "$game"
                IFS='|' read -r native mapping <<< "$(controller_status "$a")"
                if [[ "$native" == "yes" ]] || { [[ -n "$mapping" ]] && is_valid_mapping "$mapping"; }; then
                    icon="$ICON_GAMEPAD"
                else
                    icon="$ICON_KEYBOARD"
                fi
                plat=$(get_platform_icon "$i" "$l")
                display_n=$(truncate_name "$n" 22)
                padded=$(pad_to_width "  [${idx}]  ${display_n}" 34)
                box_row "${padded}${icon}  ${plat}"
                ((idx++))
            done
            box_mid "Controle"
            box_row "  [C]  Gerenciar" "  [${AMARELO}C${NC}]  Gerenciar"
            box_mid "Sair"
            box_row "  [0]  Fechar" "  [${VERMELHO}0${NC}]  Fechar"
            box_bottom
            echo ""
            read -p " > " c
            case "$c" in
                0) $DEBUG && log_debug "OK    fechando steam-cli"; prompt_exit_steam; exit 0 ; true ;;
                [bB]) $DEBUG && log_debug "OK    acessando baixar jogos"; baixar_jogos; scan_games; filter_games ; true ;;
                [cC]) $DEBUG && log_debug "OK    acessando gerenciar controles"; show_controllers_menu ; true ;;
                [1-9]|[1-9][0-9])
                    if (( c >= 1 && c <= ${#GAMES[@]} )); then
                        show_game_menu "${GAMES[$((c-1))]}"
                    else
                        invalid_option
                    fi ; true ;;
                *) invalid_option ;;
            esac
        fi
    done
}

# ===============
# MAIN
# ===============

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--debug) DEBUG=true ;;
            -v|--version) echo -e "  ${AGL} steam-cli v${VERSION}"; exit 0 ;;
            -h|--help)
                echo "uso: ./steam-cli.sh [-d] [-v] [-h]"
                echo "  -d  mostra output completo (nativo + proton)"
                echo "  -v  mostra versao"
                echo "  -h  mostra ajuda"
                exit 0 ;;
        esac; shift
    done

    if $DEBUG; then
        DEBUG_LOG="$CONFIG_DIR/debug.log"
        local ts
        ts=$(date '+%Y-%m-%d %H:%M:%S')
        if [[ ! -f "$DEBUG_LOG" ]]; then
            echo "--" > "$DEBUG_LOG"
        fi
        echo "[$ts] === INICIO SESSAO DEBUG ===" >> "$DEBUG_LOG"
        echo "[$ts] steam-cli v$VERSION" >> "$DEBUG_LOG"
    fi

    setup_config
    detect_steam_installation
    detect_libraries
    scan_games
    filter_games

    local debug_tag=""
    $DEBUG && debug_tag="[DEBUG] " || true

    if ! pgrep -x steam >/dev/null 2>&1; then
        echo -e "  ${BOLINHO} ${debug_tag}steam-cli v${VERSION} ${AGL}"
        if command -v steam &>/dev/null; then
            echo -e "  ${CINZA}[INFO] iniciando steam headless ..${NC}"
            $DEBUG && log_debug "OK    iniciando steam headless" || true
            if $DEBUG; then $STEAM_CMD -no-browser -silent &
            else $STEAM_CMD -no-browser -silent &>/dev/null & fi
            sleep 2
        else
            echo -e "  ${AMARELO}[INFO]${NC} Steam nao encontrado"
            $DEBUG && log_debug "FALHA steam binary nao encontrado" || true
        fi
    else
        echo -e "  ${BOLINHO} ${debug_tag}steam-cli v${VERSION} ${AGL}"
    fi

    show_main_menu "$@"
}

main "$@"