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

STEAM_HOME="$HOME/.steam/steam"
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

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--debug) DEBUG=true ;;
            -v|--version) echo -e "  ${AGL} STEAM_CLI v${VERSION}"; exit 0 ;;
            -h|--help)
                echo "uso: ./steam.sh [-d] [-v] [-h]"
                echo "  -d  mostra output completo (nativo + proton)"
                echo "  -v  mostra versão"
                echo "  -h  mostra ajuda"
                exit 0 ;;
        esac; shift
    done
    echo -e "${CINZA}v${VERSION} // STEAM_CLI ${AGL}${NC}"
    echo "  estrutura base carregada."
}

main "$@"