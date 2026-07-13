#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
# ===============
# DEPENDÊNCIAS
# ===============

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_ID="$ID"
    fi
}

normalize_distro_id() {
    case "$DISTRO_ID" in
        arch|manjaro|endeavouros) echo "arch" ;;
        fedora|rhel|centos)       echo "fedora" ;;
        ubuntu|debian|linuxmint)  echo "ubuntu" ;;
        *) echo "$DISTRO_ID" ;;
    esac
}

get_pkg() {
    local name="$1"
    local normalized
    normalized=$(normalize_distro_id)
    local var="${name}_${normalized}"
    if [[ -n "${!var+x}" ]]; then
        echo "${!var}"
    fi
}

check_installed() {
    local pkgs="$1"
    case "$DISTRO_ID" in
        arch|manjaro|endeavouros)
            for pkg in $pkgs; do
                pacman -Qi "$pkg" &>/dev/null || return 1
            done
            return 0
            ;;
        fedora|rhel|centos)
            for pkg in $pkgs; do
                rpm -q "$pkg" &>/dev/null || return 1
            done
            return 0
            ;;
        ubuntu|debian|linuxmint)
            for pkg in $pkgs; do
                dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" || return 1
            done
            return 0
            ;;
    esac
}

get_install_cmd() {
    case "$DISTRO_ID" in
        arch|manjaro|endeavouros) echo "sudo pacman -S" ;;
        fedora|rhel|centos)       echo "sudo dnf install" ;;
        ubuntu|debian|linuxmint)  echo "sudo apt-get install" ;;
    esac
}

dep_status_icon() {
    local pkg="$1"
    if check_installed "$pkg"; then
        echo -e "${VERDE}✔${NC}"
    else
        echo -e "${VERMELHO}✗${NC}"
    fi
}

# ===============
# INSTALAÇÃO
# ===============

install_dep() {
    local pkgs="$1" label="${2:-$1}" cmd
    cmd=$(get_install_cmd)

    if confirm_dialog "Instalar" "Executar: ${cmd} ${pkgs}?"; then
        stty echo 2>/dev/null || true
        tput cnorm 2>/dev/null || true
        clear

        $cmd $pkgs
        local exit_code=$?

        echo ""
        if [[ "$exit_code" == "0" ]]; then
            echo -e "  ${CHECK} ${label} instalado"
            echo -e "  Voltando para steam-tui..."
            $DEBUG && log_debug "[OK] ${label} instalado" || true
        else
            echo -e "  ${XIS} falha ao instalar ${label}"
            echo -e "  Voltando para steam-tui..."
            $DEBUG && log_debug "[ERROR] falha ao instalar ${label}" || true
        fi

        sleep 1.5

        tput civis 2>/dev/null || true
        stty -echo 2>/dev/null || true
    fi
}

check_deps32_status() {
    local pkgs
    pkgs=$(get_pkg "deps32")
    [[ -z "$pkgs" ]] && return
    local missing=()
    for pkg in $pkgs; do
        if ! check_installed "$pkg"; then
            missing+=("$pkg")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "  ${VERMELHO}⚠ deps32 faltando:${NC} ${missing[*]}"
    else
        echo -e "  ${CHECK} deps32"
    fi
}

show_deps_menu() {
    detect_distro

    _draw_deps_menu() {
        local sel="$1" allow_back="$2"
        local pkg_mangohud pkg_gamemode pkg_deps32
        pkg_mangohud=$(get_pkg "mangohud")
        pkg_gamemode=$(get_pkg "gamemode")
        pkg_deps32=$(get_pkg "deps32")

        local status_mangohud status_gamemode status_deps32
        status_mangohud=$(dep_status_icon "$pkg_mangohud")
        status_gamemode=$(dep_status_icon "$pkg_gamemode")
        status_deps32=$(dep_status_icon "$pkg_deps32")

        render_logo
        box_top
        box_mid "Dependências"
        box_row "  · mangohud  · gamemode  · d32" "  ${status_mangohud} mangohud  ${status_gamemode} gamemode  ${status_deps32} d32"
        box_row_blank
        box_items "$sel" "mangohud" "gamemode" "deps 32-bit" "instalar todas"
        box_bottom
        render_footer "$allow_back"
    }

    while true; do
        run_menu 4 _draw_deps_menu true
        local pkg_mangohud pkg_gamemode pkg_deps32
        pkg_mangohud=$(get_pkg "mangohud")
        pkg_gamemode=$(get_pkg "gamemode")
        pkg_deps32=$(get_pkg "deps32")
        case "$MENU_RESULT" in
            BACK) return ;;
            0) install_dep "$pkg_mangohud" "mangohud" ;;
            1) install_dep "$pkg_gamemode" "gamemode" ;;
            2) install_dep "$pkg_deps32" "deps 32-bit" ;;
            3)
                install_dep "$pkg_mangohud" "mangohud"
                install_dep "$pkg_gamemode" "gamemode"
                install_dep "$pkg_deps32" "deps 32-bit"
                ;;
        esac
    done
}
