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
    local titulo="$1" len=${#1}
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
    local pad=$((BOXW - ${#plano}))
    (( pad < 0 )) && pad=0
    local esp
    esp=$(printf '%*s' "$pad" "")
    echo -e "${AZUL}│${NC}${colorido}${esp}${AZUL}│${NC}"
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
    local i="$1" l="$2"
    local d="$l/steamapps/common/$i"
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
    local i="$1" l="$2"
    local d="$l/steamapps/common/$i"
    [[ -d "$d" ]] || return 1
    local il="${i,,}" elfs=()
    while IFS= read -r -d '' f; do
        file -b "$f" 2>/dev/null | grep -qi "ELF.*executable" && elfs+=("$f")
    done < <(find "$d" -maxdepth 2 -type f ! -name '*.*' -print0 2>/dev/null)

    local candidate=""
    for f in "${elfs[@]}"; do
        local fn; fn=$(basename "$f"); fn="${fn,,}"
        [[ "$fn" == "$il" ]] && { candidate="$f"; break; }
    done
    if [[ -z "$candidate" ]]; then
        for f in "${elfs[@]}"; do
            local fn; fn=$(basename "$f"); fn="${fn,,}"
            [[ "$fn" == *launcher* ]] && { candidate="$f"; break; }
        done
    fi
    if [[ -z "$candidate" ]]; then
        for f in "${elfs[@]}"; do
            [[ -x "$f" ]] && { candidate="$f"; break; }
        done
    fi
    [[ -z "$candidate" ]] && candidate="${elfs[0]}"
    [[ -n "$candidate" ]] && { echo "$candidate"; return 0; }

    for s in "start.sh" "launch.sh" "run.sh" "game.sh" "${il}.sh"; do
        [[ -f "$d/$s" ]] && { echo "$d/$s"; return 0; }
    done
    return 1
}

# ===============
# RUNTIME
# ===============

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
    local a="$1" n="$2" e="$3"
    local d
    d=$(dirname "$e")
    local p
    p=$(load_params "$a") || true

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
        ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}"
        return
    }

    local b
    b=$(basename "$e")
    export SteamAppId="$a" SteamGameId="$a"

    if $DEBUG; then
        log_debug "OK  binario: $e"
        if [[ -z "$p" ]]; then
            log_debug "OK  params: nenhum"
        else
            log_debug "OK  params: $p"
        fi
    fi

    (cd "$d"; if $DEBUG; then "./$b" $p; else "./$b" $p &>/dev/null; fi) &
    GAME_PID=$!; sleep 1

    if kill -0 "$GAME_PID" 2>/dev/null; then
        echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
        echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
        $DEBUG && log_debug "OK  iniciado (pid: $GAME_PID)"
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
        $DEBUG && log_debug "OK  fechado (exit: $?)"
        GAME_PID=""; return
    fi
    wait "$GAME_PID" 2>/dev/null || true

    local rt
    rt=$(find_runtime) || true
    if [[ -n "$rt" ]]; then
        $DEBUG && log_debug "OK  runtime: $rt"
        (cd "$d"; if $DEBUG; then "$rt" -- "./$b" $p; else "$rt" -- "./$b" $p &>/dev/null; fi) &
        GAME_PID=$!; sleep 1
        if kill -0 "$GAME_PID" 2>/dev/null; then
            echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
            echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
            $DEBUG && log_debug "OK  iniciado via runtime (pid: $GAME_PID)"
            wait "$GAME_PID" 2>/dev/null || true
            echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
            $DEBUG && log_debug "OK  fechado via runtime (exit: $?)"
            GAME_PID=""; return
        fi
        wait "$GAME_PID" 2>/dev/null || true
    else
        $DEBUG && log_debug "FALHA runtime nao encontrado"
    fi

    local rest=()
    while IFS= read -r -d '' f; do
        file -b "$f" 2>/dev/null | grep -qi "ELF.*executable" && [[ "$f" != "$e" ]] && rest+=("$f")
    done < <(find "$d" -maxdepth 2 -type f ! -name '*.*' -print0 2>/dev/null)

    if [[ ${#rest[@]} -gt 0 ]]; then
        local s="${rest[0]}" sn
        sn=$(basename "$s")
        $DEBUG && log_debug "OK  alternativo: $s"
        if [[ -n "$rt" ]]; then
            (cd "$d"; if $DEBUG; then "$rt" -- "./$sn" $p; else "$rt" -- "./$sn" $p &>/dev/null; fi) &
        else
            (cd "$d"; if $DEBUG; then "./$sn" $p; else "./$sn" $p &>/dev/null; fi) &
        fi
        GAME_PID=$!; sleep 1
        if kill -0 "$GAME_PID" 2>/dev/null; then
            echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
            echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
            $DEBUG && log_debug "OK  iniciado via alternativo (pid: $GAME_PID)"
            wait "$GAME_PID" 2>/dev/null || true
            echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
            $DEBUG && log_debug "OK  fechado via alternativo (exit: $?)"
            GAME_PID=""; return
        fi
        wait "$GAME_PID" 2>/dev/null || true
    fi

    echo -e "  ${XIS} ${NEGRITO}${n}${NC} nao iniciou"
    $DEBUG && log_debug "FALHA ${n} nao iniciou"
    ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}"
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
    local pl
    pl=$(get_proton_label "$a")

    [[ -z "$e" ]] && {
        echo -e "  ${XIS} .exe nao encontrado para ${NEGRITO}${n}${NC}"
        $DEBUG && log_debug "FALHA .exe nao encontrado para ${n}"
        ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}"
        return
    }

    local pr
    pr=$(get_proton "$a")

    [[ -z "$pr" ]] || [[ ! -f "$pr" ]] && {
        echo -e "  ${XIS} Proton nao encontrado para ${NEGRITO}${n}${NC}"
        echo -e "  ${CINZA}[INFO] configure ${CONFIG_DIR}/proton.conf${NC}"
        $DEBUG && log_debug "FALHA Proton nao encontrado para ${a}"
        read -p "  Enter para voltar..."; return
    }

    local cd="${d%%/common/$i}/compatdata/$a"

    if $DEBUG; then
        log_debug "OK  .exe: $e"
        log_debug "OK  proton: $pr"
        log_debug "OK  compatdata: $cd"
        log_debug "OK  STEAM_HOME: $STEAM_HOME"
    fi

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
        $DEBUG && log_debug "OK  iniciado via proton (pid: $GAME_PID)"
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
        $DEBUG && log_debug "OK  fechado via proton (exit: $?)"
    else
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${XIS} ${NEGRITO}${n}${NC} nao iniciou via Proton"
        $DEBUG && log_debug "FALHA ${n} nao iniciou via Proton"
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
        $DEBUG && debug_tag="[DEBUG] "
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
                    $DEBUG && log_debug "OK  param salvo: $novo (appid $a)"
                    echo -e "  ${CHECK} parametro salvo"
                fi ; true ;;
            2)
                save_params "$a" ""
                c=""
                $DEBUG && log_debug "OK  param limpo (appid $a)"
                echo -e "  ${CHECK} parametro limpo" ; true ;;
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
    sleep 1
    read -p "  Atualizar? (s/N): " resp
    case "${resp,,}" in
        s|sim)
            $DEBUG && log_debug "OK  atualizando v$VERSION -> v$rv"
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
    $DEBUG && debug_tag="[DEBUG] "
    echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-cli ${AGL}${NC}"
    divider
    echo -e "  ${VERDE}Manifest${NC} ~ baixar manifests Steam"
    echo ""
    if command -v manifest &>/dev/null; then
        $DEBUG && log_debug "OK  Manifest: baixando jogos"
        echo -e "  ${CINZA}github.com/aglairdev/Manifest${NC}"
        divider
        manifest
        echo ""
        echo "[scan] atualizando ..."
        scan_games
        filter_games
        echo -e "  ${CHECK} lista atualizada"
    else
        $DEBUG && log_debug "FALHA Manifest nao instalado"
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
    $DEBUG && log_debug "OK  menu: $n (appid $a)"

    local linux_exe="" win_exe="" hn=false hp=false pl=""
    linux_exe=$(find_linux_exe "$i" "$l" 2>/dev/null) || true
    if [[ -n "$linux_exe" ]]; then
        hn=true; pl="Nativo"
    else
        win_exe=$(find_game_exe "$i" "$l" 2>/dev/null) || true
        pl=$(get_proton_label "$a")
        get_proton "$a" &>/dev/null && hp=true || hp=false
    fi

    while true; do
        clear
        echo ""                                             
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] "
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-cli ${AGL}${NC}"
        box_top
        box_mid "$n"
        if [[ $hn == true ]]; then
            box_row "  [1]  Jogar (Nativo)" "  [${VERDE}1${NC}]  Jogar (Nativo)"
        elif [[ $hp == true ]]; then
            box_row "  [1]  Jogar (${pl})" "  [${VERDE}1${NC}]  Jogar (${pl})"
        else
            box_row "  [!]  Jogar (Proton nao configurado)" "  [${VERMELHO}!${NC}]  Jogar (Proton nao configurado)"
        fi
        box_row "  [2]  Parametros" "  [${AMARELO}2${NC}]  Parametros"
        box_row "  [3]  Excluir" "  [${VERMELHO}3${NC}]  Excluir"
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
            edit_params "$a" "$n"
        elif [[ "$c" == "3" ]]; then
            echo ""
            echo -e "  Excluir ${NEGRITO}${n}${NC}? (s/N)"
            read -p " > " resp
            case "${resp,,}" in
                s|sim)
                    $DEBUG && log_debug "OK  removendo jogo: $n (appid $a)"
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
        fi
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
        $DEBUG && debug_tag="[DEBUG] "
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
                0) $DEBUG && log_debug "OK  fechando steam-cli"; prompt_exit_steam; exit 0 ; true ;;
                [bB]) $DEBUG && log_debug "OK  acessando baixar jogos"; baixar_jogos; scan_games; filter_games ; true ;;
            esac
        else
            box_top
            box_mid "Loja"
            box_row "  [B]  Baixar jogos" "  [${VERDE}B${NC}]  Baixar jogos"
            box_mid "Biblioteca"
            local i=1
            for game in "${GAMES[@]}"; do
                IFS='|' read -r a n _ _ <<< "$game"
                box_row "  [${i}]  ${n}"
                ((i++))
            done
            box_mid "Sair"
            box_row "  [0]  Fechar" "  [${VERMELHO}0${NC}]  Fechar"
            box_bottom
            echo ""
            read -p " > " c
            case "$c" in
                0) $DEBUG && log_debug "OK  fechando steam-cli"; prompt_exit_steam; exit 0 ; true ;;
                [bB]) $DEBUG && log_debug "OK  acessando baixar jogos"; baixar_jogos; scan_games; filter_games ; true ;;
                [1-9]|[1-9][0-9])
                    if (( c >= 1 && c <= ${#GAMES[@]} )); then
                        show_game_menu "${GAMES[$((c-1))]}"
                    fi ; true ;;
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
    $DEBUG && debug_tag="[DEBUG] "

    if ! pgrep -x steam >/dev/null 2>&1; then
        echo -e "  ${BOLINHO} ${debug_tag}steam-cli v${VERSION} ${AGL}"
        if command -v steam &>/dev/null; then
            echo -e "  ${CINZA}[INFO] iniciando steam headless ..${NC}"
            $DEBUG && log_debug "OK  iniciando steam headless"
            if $DEBUG; then $STEAM_CMD -no-browser -silent &
            else $STEAM_CMD -no-browser -silent &>/dev/null & fi
            sleep 2
        else
            echo -e "  ${AMARELO}[INFO]${NC} Steam nao encontrado"
            $DEBUG && log_debug "FALHA steam binary nao encontrado"
        fi
    else
        echo -e "  ${BOLINHO} ${debug_tag}steam-cli v${VERSION} ${AGL}"
    fi

    show_main_menu "$@"
}

main "$@"