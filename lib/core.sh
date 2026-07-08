#
# © 2026 steam-cli ~ AGL ~ github.com/aglairdev
#
VERSION="1.0.3"
AGL="ꕤ"

STEAM_HOME=""
STEAM_CMD="steam"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/steam-cli"
DEBUG=false
DEBUG_LOG=""

REPO_URL="https://raw.githubusercontent.com/aglairdev/steam-cli/main/steam-cli.sh"
TOOLS_APPIDS=(1070560 1493710 1628350 2180100 228980 4183110)
EXTERNAL_PROGRAMS=("gamemoderun" "mangohud")

CONTROLE_DIR="$CONFIG_DIR/controle"
CONTROLLERS_DIR="$CONTROLE_DIR/jogos"
CONTROLLER_GLOBAL_CONF="$CONTROLE_DIR/global.conf"
GAMEPAD_TOOL_DIR="$CONTROLE_DIR/gamepad-tool"
GAMEPAD_TOOL_BIN="$GAMEPAD_TOOL_DIR/gamepad-tool"
GAMEPAD_TOOL_VERSION_FILE="$GAMEPAD_TOOL_DIR/.version"
GAMEPAD_TOOL_REPO_API="https://api.github.com/repos/General-Arcade/sdl2-gamepad-tool/releases/latest"
GAMEPAD_TOOL_UPDATE_AVAILABLE=""

DEPS_DIR="$CONFIG_DIR/deps"
DEPS_CONF="$DEPS_DIR/deps.conf"
DISTRO_ID=""

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
ICON_LINUX=$'\uebc6'
ICON_WINDOWS=$'\ue8e5'
ICON_TIME=$'\uf017'

DEBUG_BUFFER=()

log_debug() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    DEBUG_BUFFER+=("$msg")
    echo "[$ts] $msg" >> "$DEBUG_LOG"
}

debug_flush() {
    $DEBUG || { DEBUG_BUFFER=(); return 0; }
    local m
    for m in "${DEBUG_BUFFER[@]}"; do
        echo -e "  ${CINZA}[DEBUG] ${m}${NC}"
    done
    DEBUG_BUFFER=()
}

divider() {
    echo -e "${AZUL}-----------------------------------------------${NC}"
}

loading_dots() {
    local s=$1 i=0
    local frames=("." ".." "...")
    while (( i < s * 3 )); do
        printf "\r  ${CINZA}%s${NC}" "${frames[$((i % 3))]}"
        sleep 0.33
        i=$((i + 1))
    done
    printf "\r                    \r"
}

invalid_option() {
    echo -e "  ${VERMELHO}Comando não disponível.${NC}"
    read -n1 -s -r
}

check_external_program() {
    command -v "$1" &>/dev/null
}

detect_params_programs() {
    local params="$1"
    local found=()
    for prog in "${EXTERNAL_PROGRAMS[@]}"; do
        if [[ "$params" == *"$prog"* ]]; then
            found+=("$prog")
        fi
    done
    echo "${found[@]}"
}

show_params_programs_status() {
    local params="$1"
    local programs=()
    read -ra programs <<< "$(detect_params_programs "$params")"
    for prog in "${programs[@]}"; do
        if check_external_program "$prog"; then
            echo -e "  ${CHECK} ${prog}"
        else
            echo -e "  ${XIS} ${prog} ~ não encontrado"
        fi
    done
}

