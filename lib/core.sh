#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
# ===============
# CONFIGURAÇÃO
# ===============

VERSION="2.0.5"
AGL="ꕤ"

STEAM_HOME=""
STEAM_CMD="steam"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/steam-tui"
DEBUG=false
DEBUG_LOG=""

CORE_URL="https://raw.githubusercontent.com/aglairdev/steam-tui/main/lib/core.sh"
MAIN_URL="https://raw.githubusercontent.com/aglairdev/steam-tui/main/steam-tui"

TOOLS_APPIDS=(1070560 1493710 1628350 2180100 228980 4183110)
EXTERNAL_PROGRAMS=("gamemoderun" "mangohud")
RUNTIME_INCOMPATIBLE_APPIDS=(504230)

CONTROLLER_DIR="$CONFIG_DIR/controle"
CONTROLLERS_DIR="$CONTROLLER_DIR/jogos"
CONTROLLER_GLOBAL_CONF="$CONTROLLER_DIR/global.conf"
GAMEPAD_TOOL_DIR="$CONTROLLER_DIR/gamepad-tool"
GAMEPAD_TOOL_BIN="$GAMEPAD_TOOL_DIR/gamepad-tool"
GAMEPAD_TOOL_VERSION_FILE="$GAMEPAD_TOOL_DIR/.version"
GAMEPAD_TOOL_REPO_API="https://api.github.com/repos/General-Arcade/sdl2-gamepad-tool/releases/latest"
GAMEPAD_TOOL_UPDATE_AVAILABLE=""

DEPS_DIR="$CONFIG_DIR/deps"
DEPS_CONF="$DEPS_DIR/deps.conf"
DISTRO_ID=""

# ===============
# CORES
# ===============

VERDE='\033[38;2;120;170;120m'
VERMELHO='\033[38;2;190;100;100m'
VERMELHO_CLARO='\033[38;2;255;150;150m'
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
GAME_MENU_NEEDS_RESYNC=false
CHECK="✔"
XIS="✘"
BOLINHO="${VERDE}●${NC}"

ICON_GAMEPAD=$'\uf11b'
ICON_KEYBOARD=$'\uf11c'
ICON_LINUX=$'\uebc6'
ICON_WINDOWS=$'\ue8e5'
ICON_TIME=$'\uf017'

# ===============
# LOG DEBUG
# ===============

log_debug() {
    local msg="$1"
    local timestamp
    timestamp=$(date '+%d-%m-%Y %H:%M:%S')
    echo "[$timestamp] $msg" >> "$DEBUG_LOG"
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
