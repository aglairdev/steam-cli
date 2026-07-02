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
CHECK="✔"
XIS="✘"
BOLINHO="●"

divider() {
    echo -e "${AZUL}-----------------------------------------------${NC}"
}

section_divider() {
    local name="$1" total=47 
    local len=${#name}
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
# LANCAMENTO NATIVO
# ===============

launch_native() {
    local a="$1" n="$2" i="$3" l="$4"
    local d="$l/steamapps/common/$i"
    local p
    p=$(load_params "$a") || true

    local e
    e=$(find_linux_exe "$i" "$l") || true

    if [[ -n "$e" ]] && [[ ! -x "$e" ]]; then
        echo -e "  ${AMARELO}[INFO]${NC} sem permissao: $(basename "$e")"
        read -p "  Adicionar? (s/N): " perm
        case "${perm,,}" in s|sim) chmod +x "$e" 2>/dev/null || true ;; *) e="" ;; esac
    fi

    [[ -z "$e" ]] && {
        echo -e "  ${XIS} ${n} nao tem binario nativo"
        echo -e "  ${CINZA}[INFO] use -d${NC}"
        return
    }

    local b
    b=$(basename "$e")
    export SteamAppId="$a" SteamGameId="$a"

    # 1a. Tenta direto
    (cd "$d"; if $DEBUG; then "./$b" $p; else "./$b" $p &>/dev/null; fi) &
    GAME_PID=$!; sleep 1

    if kill -0 "$GAME_PID" 2>/dev/null; then
        echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
        echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"; GAME_PID=""; return
    fi
    wait "$GAME_PID" 2>/dev/null || true

    # 1b. Falhou ~ tenta runtime
    local rt
    rt=$(find_runtime) || true
    if [[ -n "$rt" ]]; then
        (cd "$d"; if $DEBUG; then "$rt" -- "./$b" $p; else "$rt" -- "./$b" $p &>/dev/null; fi) &
        GAME_PID=$!; sleep 1
        if kill -0 "$GAME_PID" 2>/dev/null; then
            echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
            echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
            wait "$GAME_PID" 2>/dev/null || true
            echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"; GAME_PID=""; return
        fi
        wait "$GAME_PID" 2>/dev/null || true
    fi

    # 1c. Tenta binario alternativo
    local rest=()
    while IFS= read -r -d '' f; do
        file -b "$f" 2>/dev/null | grep -qi "ELF.*executable" && [[ "$f" != "$e" ]] && rest+=("$f")
    done < <(find "$d" -maxdepth 1 -type f ! -name '*.*' -print0 2>/dev/null)

    if [[ ${#rest[@]} -gt 0 ]]; then
        local s="${rest[0]}" sn
        sn=$(basename "$s")
        if [[ -n "$rt" ]]; then
            (cd "$d"; if $DEBUG; then "$rt" -- "./$sn" $p; else "$rt" -- "./$sn" $p &>/dev/null; fi) &
        else
            (cd "$d"; if $DEBUG; then "./$sn" $p; else "./$sn" $p &>/dev/null; fi) &
        fi
        GAME_PID=$!; sleep 1
        if kill -0 "$GAME_PID" 2>/dev/null; then
            echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
            echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
            wait "$GAME_PID" 2>/dev/null || true
            echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"; GAME_PID=""; return
        fi
        wait "$GAME_PID" 2>/dev/null || true
    fi

    echo -e "  ${XIS} ${NEGRITO}${n}${NC} nao iniciou"
    ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}"
    GAME_PID=""
}

# ===============
# LANCAMENTO PROTON
# ===============

launch_proton() {
    local a="$1" n="$2" i="$3" l="$4"
    local d="$l/steamapps/common/$i"
    local p
    p=$(load_params "$a") || true
    local pl
    pl=$(get_proton_label "$a")

    local e
    e=$(find_game_exe "$i" "$l") || true

    [[ -z "$e" ]] && {
        echo -e "  ${XIS} .exe nao encontrado para ${NEGRITO}${n}${NC}"
        ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}"
        return
    }

    local pr
    pr=$(get_proton "$a")
    local cd="$l/steamapps/compatdata/$a"

    [[ -z "$pr" ]] || [[ ! -f "$pr" ]] && {
        echo -e "  ${XIS} Proton nao encontrado para ${NEGRITO}${n}${NC}"
        echo -e "  ${CINZA}[INFO] configure ${CONFIG_DIR}/proton.conf${NC}"
        read -p "  Enter para voltar..."; return
    }

    mkdir -p "$cd"
    export STEAM_COMPAT_DATA_PATH="$cd"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_HOME"
    export SteamAppId="$a" SteamGameId="$a"

    echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (${pl})"

    if $DEBUG; then "$pr" run "$e" $p &
    else "$pr" run "$e" $p &>/dev/null & fi
    GAME_PID=$!; sleep 1

    if kill -0 "$GAME_PID" 2>/dev/null; then
        echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
    else
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${XIS} ${NEGRITO}${n}${NC} nao iniciou via Proton"
        ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}"
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
}
trap cleanup EXIT INT TERM

# ===============
# PARAMETROS
# ===============

edit_params() {
    local a="$1" n="$2"
    local c
    c=$(load_params "$a" 2>/dev/null) || true

    while true; do
        clear
        echo -e "${CINZA}v${VERSION} // STEAM_CLI ${AGL}${NC}"
        section_divider "Parametros"
        echo ""
        echo -e "  ${NEGRITO}${n}${NC}"
        echo ""
        echo -e "  Atual: ${CINZA}${c:-(vazio)}${NC}"
        echo ""
        echo -e "  [1]  Editar"
        echo -e "  [2]  Limpar"
        echo -e "  [${VERMELHO}0${NC}]  Voltar"
        echo ""
        read -p " > " opt
        case "$opt" in
            1)
                echo ""
                read -e -p " > " novo
                if [[ -n "$novo" ]]; then
                    save_params "$a" "$novo"
                    c="$novo"
                    echo -e "  ${CHECK} parametro salvo"
                fi
                sleep 1 ;;
            2)
                save_params "$a" ""
                c=""
                echo -e "  ${CHECK} parametro limpo"
                sleep 1 ;;
            0) return ;;
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
    echo ""
    read -p " > " resp
    case "${resp,,}" in
        s|sim)
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
            fi ;;
    esac
}

# ===============
# BAIXAR JOGOS
# ===============

baixar_jogos() {
    clear
    echo -e "\n${CINZA}v${VERSION} // STEAM_CLI ${AGL}${NC}"
    divider
    echo ""
    echo -e "  ${BOLINHO} ${VERDE}Manifest${NC} - baixar manifests Steam"
    echo ""
    if command -v manifest &>/dev/null; then
        echo -e "  ${CINZA}github.com/aglairdev/Manifest${NC}"
        echo ""
        divider
        echo ""
        manifest
        echo ""
        echo "[scan] atualizando ..."
        scan_games
        filter_games
        echo -e "  ${CHECK} lista atualizada"
    else
        echo -e "  ${AMARELO}[INFO]${NC} Manifest nao encontrado"
        echo -e "  ${CINZA}github.com/aglairdev/Manifest${NC}"
    fi
    echo ""
    read -p "  Enter para voltar"
}

# ===============
# MENU DO JOGO
# ===============

show_game_menu() {
    local game="$1"
    IFS='|' read -r a n i l <<< "$game"

    local hn hp pl
    if find_linux_exe "$i" "$l" &>/dev/null; then
        hn=true; hp=false; pl="Nativo"
    else
        hn=false
        pl=$(get_proton_label "$a")
        get_proton "$a" &>/dev/null && hp=true || hp=false
    fi

    while true; do
        clear
        echo ""
        echo -e "${CINZA}v${VERSION} // STEAM_CLI ${AGL}${NC}"
        section_divider "$n"
        echo ""
        if $hn; then
            echo -e "  [1]  Jogar (Nativo)"
        elif $hp; then
            echo -e "  [1]  Jogar (${pl})"
        else
            echo -e "  [!]  Jogar (Proton nao configurado)"
        fi
        echo -e "  [2]  Parametros"
        echo -e "  [${VERMELHO}3${NC}]  Excluir"
        section_divider "Sair"
        echo -e "  [${VERMELHO}0${NC}]  Voltar"
        echo ""
        read -p " > " c

        case "$c" in
            1)
                if $hn; then launch_native "$a" "$n" "$i" "$l"
                elif $hp; then launch_proton "$a" "$n" "$i" "$l"
                fi
                read -p "  Enter para continuar..." ;;
            2) edit_params "$a" "$n" ;;
            3)
                echo ""
                echo -e "  Excluir ${NEGRITO}${n}${NC}? (s/N)"
                read -p " > " resp
                case "${resp,,}" in
                    s|sim)
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
                        GAMES=("${ng[@]}"); sleep 1; return ;;
                esac ;;
            0) return ;;
        esac
    done
}

# ===============
# MENU PRINCIPAL
# ===============

show_main_menu() {
    while true; do
        clear
        echo ""
        echo -e "${CINZA}v${VERSION} // STEAM_CLI ${AGL}${NC}"

        if [[ ${#GAMES[@]} -eq 0 ]]; then
            section_divider "Loja"
            echo -e "  [${VERDE}B${NC}]  Baixar jogos"
            section_divider "Sair"
            echo -e "  [${VERMELHO}0${NC}]  Fechar"
            echo ""
            read -p " > " c
            case "$c" in
                0) prompt_exit_steam; exit 0 ;;
                [bB]) baixar_jogos; scan_games; filter_games ;;
            esac
        else
            section_divider "Loja"
            echo -e "  [${VERDE}B${NC}]  Baixar jogos"
            section_divider "Biblioteca"
            local i=1
            for game in "${GAMES[@]}"; do
                IFS='|' read -r a n _ _ <<< "$game"
                echo -e "  [${i}]  ${n}"
                ((i++))
            done
            section_divider "Sair"
            echo -e "  [${VERMELHO}0${NC}]  Fechar"
            echo ""
            read -p " > " c
            case "$c" in
                0) prompt_exit_steam; exit 0 ;;
                [bB]) baixar_jogos; scan_games; filter_games ;;
                [1-9]|[1-9][0-9])
                    (( c >= 1 && c <= ${#GAMES[@]} )) \
                        && show_game_menu "${GAMES[$((c-1))]}" ;;
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

    if ! pgrep -x steam >/dev/null 2>&1; then
        echo -e "  ${BOLINHO} STEAM_CLI v${VERSION} ${AGL}"
        if command -v steam &>/dev/null; then
            echo -e "  ${CINZA}[INFO] iniciando steam headless ..${NC}"
            if $DEBUG; then $STEAM_CMD -no-browser -silent &
            else $STEAM_CMD -no-browser -silent &>/dev/null & fi
            sleep 2
        else
            echo -e "  ${AMARELO}[INFO]${NC} Steam nao encontrado"
        fi
    else
        echo -e "  ${BOLINHO} STEAM_CLI v${VERSION} ${AGL}"
    fi

    check_update "$@"
    show_main_menu
}

main "$@"