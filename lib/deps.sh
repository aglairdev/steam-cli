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
    local norm
    norm=$(normalize_distro_id)
    local var="${name}_${norm}"
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
        ubuntu|debian|linuxmint)  echo "sudo apt install" ;;
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

install_dep() {
    local pkgs="$1"
    local cmd
    cmd=$(get_install_cmd)
    echo ""
    echo -e "  ${CINZA}Comando:${NC} $cmd $pkgs"
    read -p "  Executar? (s/N): " resp
    case "${resp,,}" in
        s|sim)
            if $cmd $pkgs; then
                echo -e "  ${CHECK} concluído"
            else
                echo -e "  ${XIS} falha na instalação"
            fi
            ;;
    esac
    loading_dots 1
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

    while true; do
        local pkg_mangohud pkg_gamemode pkg_deps32
        pkg_mangohud=$(get_pkg "mangohud")
        pkg_gamemode=$(get_pkg "gamemode")
        pkg_deps32=$(get_pkg "deps32")

        local s_m s_g s_d
        s_m=$(dep_status_icon "$pkg_mangohud")
        s_g=$(dep_status_icon "$pkg_gamemode")
        s_d=$(dep_status_icon "$pkg_deps32")

        clear
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-tui ${AGL}${NC}"
        box_top
        box_mid "Dependências"
        box_row "  · mangohud  · gamemode  · d32" "  ${s_m} mangohud  ${s_g} gamemode  ${s_d} d32"
        box_row ""
        box_row "  [1]  mangohud" "  [${AMARELO}1${NC}]  mangohud"
        box_row "  [2]  gamemode" "  [${AMARELO}2${NC}]  gamemode"
        box_row "  [3]  deps 32-bit" "  [${AMARELO}3${NC}]  deps 32-bit"
        box_row "  [4]  instalar todas" "  [${AMARELO}4${NC}]  instalar todas"
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        debug_flush
        echo ""
        read -p " > " c

        case "$c" in
            1) install_dep "$pkg_mangohud" ;;
            2) install_dep "$pkg_gamemode" ;;
            3) install_dep "$pkg_deps32" ;;
            4)
                install_dep "$pkg_mangohud"
                install_dep "$pkg_gamemode"
                install_dep "$pkg_deps32"
                ;;
            0) return ;;
            *) invalid_option ;;
        esac
    done
}

show_config_menu() {
    while true; do
        clear
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-tui ${AGL}${NC}"
        box_top
        box_mid "Config"
        box_row "  [1]  Controle" "  [${AMARELO}1${NC}]  Controle"
        box_row "  [2]  Dependências" "  [${AMARELO}2${NC}]  Dependências"
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        debug_flush
        echo ""
        read -p " > " c

        case "$c" in
            1) show_controllers_menu ;;
            2) show_deps_menu ;;
            0) return ;;
            *) invalid_option ;;
        esac
    done
}

