#!/usr/bin/env bash
#
# steam_cli ~ biblioteca de jogos steam via terminal
# © 2026 steam_cli ~ AGL ~ github.com/aglairdev
# Licenca: MIT
#
# uso:  ./steam.sh
#       ./steam.sh -d     #debug
#       ./steam.sh -v     #versão
#       ./steam.sh -h     #ajuda
#

set -euo pipefail

VERSION="1.0.0"
AGL="ꕤ"

STEAM_HOME=""
STEAM_CMD="steam"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/steam_cli"
DEBUG=false

REPO_URL="https://raw.githubusercontent.com/aglairdev/STEAM_CLI/main/steam_cli.sh"
TOOLS_APPIDS=(1070560 1493710 1628350 2180100 228980 4183110)

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

divider() {
    echo -e "${AZUL}-----------------------------------------------${NC}"
}

section_divider() {
    local name="$1" total=47 len=${#name}
    local dash=$(( (total - len - 2) / 2 )) d="" e=""
    for ((i=0; i<dash; i++)); do d+="-"; done
    for ((i=0; i<total - len - 2 - dash*2; i++)); do e+="-"; done
    echo -e "${AZUL}${d} ${name} ${d}${e}${NC}"
}

# ===============
# SETUP
# ===============

setup_config() {
    mkdir -p "$CONFIG_DIR/params"
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
            return 0
        fi
    fi

    if [[ -d "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam" ]]; then
        STEAM_HOME="$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"
        STEAM_CMD="flatpak run com.valvesoftware.Steam"
        return 0
    fi

    if [[ -d "$HOME/snap/steam/common/.steam/steam" ]]; then
        STEAM_HOME="$HOME/snap/steam/common/.steam/steam"
        STEAM_CMD="steam"
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
            return 0
        fi
    fi

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
            fi
        done < "$vdf"
        return 0
    done
    echo -e "  ${XIS} libraryfolders.vdf nao encontrado" >&2
    exit 1
}

# ===============
# SCAN JOGOS
# ===============

scan_games() {
    GAMES=()
    for lib in "${LIBRARIES[@]}"; do
        local d="$lib/steamapps"
        [[ -d "$d" ]] || continue
        while IFS= read -r m; do
            [[ -f "$m" ]] || continue
            local a n i
            a=$(grep '"appid"' "$m" | sed 's/.*"appid"[[:space:]]*"\(.*\)"/\1/')
            n=$(grep '"name"' "$m" | sed 's/.*"name"[[:space:]]*"\(.*\)"/\1/')
            i=$(grep '"installdir"' "$m" | sed 's/.*"installdir"[[:space:]]*"\(.*\)"/\1/')
            GAMES+=("$a|$n|$i|$lib")
        done < <(find "$d" -maxdepth 1 -name 'appmanifest_*.acf' \
            -exec stat --format='%Y %n' {} \; 2>/dev/null | sort -n | cut -d' ' -f2-)
    done
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
}

# ===============
# DETECCAO EXECUTAVEIS
# ===============

find_game_exe() {
    local i="$1" l="$2" d="$l/steamapps/common/$i"
    [[ -d "$d" ]] || return 1
    local exes=()
    while IFS= read -r -d '' e; do
        local b=$(basename "$e"); b="${b,,}"
        case "$b" in
            uninstall*|unins*|*redist*|vcredist*|dxwebsetup*|dotnet*|*setup*) continue ;;
        esac
        exes+=("$e")
    done < <(find "$d" -maxdepth 2 -name '*.exe' -type f -print0 2>/dev/null)
    case ${#exes[@]} in
        0) return 1 ;;
        1) echo "${exes[0]}" ;;
        *)
            local dl="${i,,}"
            for e in "${exes[@]}"; do
                local en=$(basename "$e" .exe); en="${en,,}"
                [[ "$en" == "$dl" ]] && { echo "$e"; return 0; }
            done
            echo "${exes[0]}" ;;
    esac
}

find_linux_exe() {
    local i="$1" l="$2" d="$l/steamapps/common/$i"
    [[ -d "$d" ]] || return 1
    local elfs=()
    while IFS= read -r -d '' f; do
        file -b "$f" 2>/dev/null | grep -qi "ELF.*executable" && elfs+=("$f")
    done < <(find "$d" -maxdepth 1 -type f ! -name '*.*' -print0 2>/dev/null)
    [[ ${#elfs[@]} -gt 0 ]] && { echo "${elfs[0]}"; return 0; }
    local il="${i,,}"
    for s in "start.sh" "launch.sh" "run.sh" "game.sh" "${il}.sh"; do
        [[ -f "$d/$s" ]] && { echo "$d/$s"; return 0; }
    done
    return 1
}

find_runtime() {
    for l in "${LIBRARIES[@]}"; do
        for r in "SteamLinuxRuntime_sniper" "SteamLinuxRuntime_4" "SteamLinuxRuntime"; do
            local b="$l/steamapps/common/$r/run"
            [[ -x "$b" ]] && { echo "$b"; return 0; }
        done
    done
    return 1
}

# ===============
# PROTON
# ===============

get_proton() {
    local a="$1" v="PROTON_${a}"
    [[ -n "${!v:-}" ]] && { echo "${!v}"; return; }
    if [[ -n "${PROTON_DEFAULT:-}" ]] && [[ -f "$PROTON_DEFAULT" ]]; then
        echo "$PROTON_DEFAULT"; return
    fi
    for l in "${LIBRARIES[@]}"; do
        local pd="$l/steamapps/common"
        [[ -d "$pd" ]] || continue
        while IFS= read -r -d '' p; do
            [[ -x "$p" ]] && { echo "$p"; return; }
        done < <(find "$pd" -maxdepth 3 -name 'proton' -type f -print0 2>/dev/null)
    done
    echo ""
}

get_proton_label() {
    local p
    p=$(get_proton "$1")
    [[ -z "$p" ]] && { echo "Proton"; return; }
    basename "$(dirname "$p")"
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
# MAIN
# ===============

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--debug) DEBUG=true ;;
            -v|--version) echo -e "  ${AGL} STEAM_CLI v${VERSION}"; exit 0 ;;
            -h|--help)
                echo "uso: ./steam.sh [-d] [-v] [-h]"
                echo "  -d  mostra output completo (nativo + proton)"
                echo "  -v  mostra versao"
                echo "  -h  mostra ajuda"
                exit 0 ;;
        esac; shift
    done

    setup_config
    detect_steam_installation
    detect_libraries
    scan_games
    filter_games

    echo -e "${CINZA}v${VERSION} // STEAM_CLI ${AGL}${NC}"
    echo ""
    if [[ ${#GAMES[@]} -eq 0 ]]; then
        echo -e "  ${AMARELO}Nenhum jogo encontrado${NC}"
    else
        local i=1
        for game in "${GAMES[@]}"; do
            IFS='|' read -r a n _ _ <<< "$game"
            echo -e "  [${i}]  ${n}"
            ((i++))
        done
    fi
}

main "$@"