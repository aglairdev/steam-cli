#!/usr/bin/env bash
#
# steam-cli ~ biblioteca de jogos steam via terminal
# © 2026 steam-cli ~ AGL ~ github.com/aglairdev
# Licença: MIT
#
# uso:  ./steam-cli.sh
#       ./steam-cli.sh -d     #debug
#       ./steam-cli.sh -v     #versão
#       ./steam-cli.sh -h     #ajuda
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/deps.sh"
source "$SCRIPT_DIR/lib/steam.sh"
source "$SCRIPT_DIR/lib/games.sh"
source "$SCRIPT_DIR/lib/controller.sh"
source "$SCRIPT_DIR/lib/menus.sh"

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
                echo "  -v  mostra versão"
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
        echo "[$ts] === INÍCIO SESSAO ===" >> "$DEBUG_LOG"
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
            loading_dots 2
        else
            echo -e "  ${AMARELO}[INFO]${NC} Steam não encontrado"
            $DEBUG && log_debug "FALHA steam binário não encontrado" || true
        fi
    else
        echo -e "  ${BOLINHO} ${debug_tag}steam-cli v${VERSION} ${AGL}"
    fi

    show_main_menu "$@"
}

main "$@"