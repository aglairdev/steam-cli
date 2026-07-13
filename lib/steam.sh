#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
# ===============
# DETECÇÃO STEAM
# ===============

detect_steam_installation() {
    if command -v steam &>/dev/null; then
        if [[ -d "$HOME/.steam/steam" ]]; then
            STEAM_HOME="$HOME/.steam/steam"
            STEAM_CMD="steam"
            $DEBUG && log_debug "[OK] steam nativo encontrado: $STEAM_HOME" || true
            return 0
        fi
    fi

    if [[ -d "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam" ]]; then
        STEAM_HOME="$HOME/.var/app/com.valvesoftware.Steam/.steam/steam"
        STEAM_CMD="flatpak run com.valvesoftware.Steam"
        $DEBUG && log_debug "[OK] steam flatpak encontrado: $STEAM_HOME" || true
        return 0
    fi

    if [[ -d "$HOME/snap/steam/common/.steam/steam" ]]; then
        STEAM_HOME="$HOME/snap/steam/common/.steam/steam"
        STEAM_CMD="steam"
        $DEBUG && log_debug "[OK] steam snap encontrado: $STEAM_HOME" || true
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
            $DEBUG && log_debug "[OK] steam encontrado via PATH: $STEAM_HOME" || true
            return 0
        fi
    fi

    $DEBUG && log_debug "[ERROR] steam não encontrado (nativo / flatpak / snap)" || true
    debug_flush
    echo -e "  ${XIS} Steam não encontrado (nativo / flatpak / snap)"
    exit 1
}

# ===============
# DETECÇÃO BIBLIOTECAS
# ===============

detect_libraries() {
    local vdf
    for vdf in "$STEAM_HOME/steamapps/libraryfolders.vdf" \
               "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"; do
        [[ -f "$vdf" ]] || continue
        while IFS= read -r line; do
            if [[ $line =~ ^[[:space:]]*\"path\"[[:space:]]*\"(.*)\" ]]; then
                local library="${BASH_REMATCH[1]}"
                library="${library/#\~/$HOME}"
                LIBRARIES+=("$library")
                $DEBUG && log_debug "[OK] biblioteca: $library" || true
            fi
        done < "$vdf"
        return 0
    done
    $DEBUG && log_debug "[ERROR] libraryfolders.vdf não encontrado" || true
    debug_flush
    echo -e "  ${XIS} libraryfolders.vdf não encontrado" >&2
    exit 1
}

# ===============
# SCAN JOGOS
# ===============

scan_games() {
    $DEBUG && log_debug "[OK] varredura de jogos iniciada" || true
    local temp=()
    for library in "${LIBRARIES[@]}"; do
        local steamapps_dir="$library/steamapps"
        [[ -d "$steamapps_dir" ]] || continue
        while IFS= read -r manifest; do
            [[ -f "$manifest" ]] || continue
            local appid name installdir last_played timestamp platform playtime
            appid=$(grep '"appid"' "$manifest" | sed 's/.*"appid"[[:space:]]*"\(.*\)"/\1/') || true
            name=$(grep '"name"' "$manifest" | sed 's/.*"name"[[:space:]]*"\(.*\)"/\1/') || true
            installdir=$(grep '"installdir"' "$manifest" | sed 's/.*"installdir"[[:space:]]*"\(.*\)"/\1/') || true
            last_played=$(grep '"LastPlayed"' "$manifest" | sed 's/.*"LastPlayed"[[:space:]]*"\(.*\)"/\1/') || true
            playtime=$(grep '"Playtime"' "$manifest" | sed 's/.*"Playtime"[[:space:]]*"\(.*\)"/\1/') || true
            timestamp=${last_played:-$(stat --format='%Y' "$manifest" 2>/dev/null || echo 0)}
            platform="windows"
            local game_dir="$library/steamapps/common/$installdir"
            if [[ -d "$game_dir" ]]; then
                while IFS= read -r -d '' bin; do
                    if file -b "$bin" 2>/dev/null | grep -qi "ELF.*executable"; then
                        platform="linux"; break
                    fi
                done < <(find "$game_dir" -maxdepth 2 -type f ! -name '*.*' -print0 2>/dev/null)
            fi
            temp+=("$timestamp|$appid|$name|$installdir|$library|$platform|${playtime:-0}")
        done < <(find "$steamapps_dir" -maxdepth 1 -name 'appmanifest_*.acf' \
            -exec stat --format='%Y %n' {} \; 2>/dev/null | sort -n | cut -d' ' -f2-)
    done
    IFS=$'\n' temp=($(sort -t'|' -k1 -rn <<< "${temp[*]}"))
    unset IFS
    GAMES=()
    for entry in "${temp[@]}"; do
        GAMES+=("${entry#*|}")
    done
    $DEBUG && log_debug "[OK] ${#GAMES[@]} jogos encontrados" || true
}

# ===============
# FILTRO
# ===============

filter_games() {
    local filtered=()
    for game in "${GAMES[@]}"; do
        IFS='|' read -r appid name _ _ _ _ _ <<< "$game"
        local is_tool=0
        for tool_id in "${TOOLS_APPIDS[@]}"; do
            [[ "$appid" == "$tool_id" ]] && { is_tool=1; break; }
        done
        [[ $is_tool -eq 0 ]] || continue
        local name_lower="${name,,}"
        case "$name_lower" in
            *proton*) continue ;;
            *"steam linux runtime"*) continue ;;
            *steamworks*) continue ;;
        esac
        filtered+=("$game")
    done
    GAMES=("${filtered[@]}")
    $DEBUG && log_debug "[OK] ${#GAMES[@]} jogos após filtro" || true
}

# ===============
# STEAM
# ===============

prompt_exit_steam() {
    pgrep -x steam >/dev/null 2>&1 || return
    if confirm_dialog "Sair" "Sair da Steam?"; then
        status_box_start "Steam"
        status_box_add "finalizando Steam .."
        $STEAM_CMD -shutdown 2>/dev/null
        sleep 1; wait 2>/dev/null
        status_box_add "${CHECK} steam finalizado"
        sleep 0.6
        clear
        exit 0
    fi
}

cleanup() {
    tput cnorm 2>/dev/null || true
    stty echo 2>/dev/null || true
    if [[ -n "$GAME_PID" ]] && kill -0 "$GAME_PID" 2>/dev/null; then
        echo ""
        echo -e "  ${AMARELO}[WARN]${NC} encerrando jogo (pid: ${GAME_PID})"
        kill -- "-$GAME_PID" 2>/dev/null || true
        wait "$GAME_PID" 2>/dev/null || true
    fi
    if $DEBUG && [[ -n "$DEBUG_LOG" ]]; then
        local timestamp
        timestamp=$(date '+%d-%m-%Y %H:%M:%S')
        echo "[$timestamp] === FIM DA SESSAO ===" >> "$DEBUG_LOG"
        echo "--" >> "$DEBUG_LOG"
    fi
}
trap cleanup EXIT INT TERM

# ===============
# UPDATE
# ===============

check_update() {
    [[ -z "$CORE_URL" ]] && return
    local remote_version
    remote_version=$(curl -s --connect-timeout 3 "$CORE_URL" | grep '^VERSION=' | head -1 | cut -d'"' -f2) || true
    [[ -z "$remote_version" ]] || [[ "$remote_version" == "$VERSION" ]] && return

    if confirm_dialog "Atualização" "Nova versão v${remote_version} disponível (atual v${VERSION}). Atualizar?"; then
        $DEBUG && log_debug "[OK] atualizando v$VERSION -> v$remote_version" || true
        loading_dots 1 "Baixando v${remote_version}"
        local tmp
        tmp=$(mktemp)
        if curl -sL --connect-timeout 10 "$MAIN_URL" -o "$tmp"; then
            chmod +x "$tmp"
            cat "$tmp" > "$0"
            rm -f "$tmp"

            local LIB_URL="https://raw.githubusercontent.com/aglairdev/steam-tui/main/lib"
            local LIB_MODULES=(core.sh responsiveness.sh ui.sh logo.sh config.sh deps.sh steam.sh games.sh controller.sh menus.sh)
            for module in "${LIB_MODULES[@]}"; do
                curl -sL -f "$LIB_URL/$module" -o "$SCRIPT_DIR/lib/$module" || {
                    ui_log "${XIS} falha ao atualizar ${module}"
                    rm -f "$tmp"; return
                }
            done

            ui_log "${CHECK} atualizado, reiniciando"
            exec "$0" "$@"
        else
            ui_log "${XIS} falha no download"
            rm -f "$tmp"
        fi
    fi
}
# ===============
# BAIXAR JOGOS
# ===============

baixar_jogos() {
    status_box_start "Baixar Jogos"
    STATUS_BOX_LINES+=("Manifest")
    status_box_add "${AZUL}github.com/aglairdev/manifest${NC}"
    sleep 2

    if command -v manifest &>/dev/null; then
        $DEBUG && log_debug "[OK] Manifest: baixando jogos" || true
        loading_dots 1 "Abrindo Manifest"
        clear
        tput cup 0 0
        stty echo 2>/dev/null || true
        tput cnorm 2>/dev/null || true
        manifest
        tput civis 2>/dev/null || true
        stty -echo 2>/dev/null || true
        clear
        loading_dots 3 "Atualizando biblioteca"
        scan_games
        filter_games
        status_box_start "Baixar Jogos"
        status_box_add "${CHECK} Biblioteca atualizada"
        sleep 1.2
    else
        $DEBUG && log_debug "[ERROR] Manifest não instalado" || true
        status_box_add "${AMARELO}Manifest não encontrado${NC}"
        sleep 1.5
    fi
}
