#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
exec_game() {
    local dir="$1"
    local exe="$2"
    local params="$3"
    local is_debug="$4"

    local game_cmd="./$exe"
    local final_cmd

    if [[ "$params" == *"%command%"* ]]; then
        final_cmd="${params//%command%/$game_cmd}"
    else
        final_cmd="$params $game_cmd"
    fi

    if $is_debug; then
        (cd "$dir"; eval "$final_cmd" 2>&1 | grep -v -E '^gamemodeauto:') &
    else
        (cd "$dir"; eval "$final_cmd" &>/dev/null) &
    fi
}


# ===============
# DETECÇÃO EXECUTÁVEIS
# ===============

find_game_exe() {
    local i="$1" l="$2"
    local d="$l/steamapps/common/$i"
    [[ -d "$d" ]] || { $DEBUG && log_debug "EXE   diretório não encontrado: $d"; return 1; }
    local exes=()
    while IFS= read -r -d '' e; do
        local b=$(basename "$e"); b="${b,,}"
        case "$b" in
            uninstall*|unins*|*redist*|vcredist*|dxwebsetup*|dotnet*|*setup*) continue ;;
        esac
        exes+=("$e")
    done < <(find "$d" -maxdepth 4 -name '*.exe' -type f -print0 2>/dev/null)
    $DEBUG && log_debug "EXE   ${#exes[@]} executáveis .exe encontrados em $i" || true
    case ${#exes[@]} in
        0) $DEBUG && log_debug "FALHA nenhum .exe encontrado para $i"; return 1 ;;
        1) $DEBUG && log_debug "OK    exe selecionado: ${exes[0]}"; echo "${exes[0]}" ;;
        *)
            local dl="${i,,}"
            for e in "${exes[@]}"; do
                local en=$(basename "$e" .exe); en="${en,,}"
                if [[ "$en" == "$dl" ]]; then
                    $DEBUG && log_debug "OK    exe por nome: $e" || true
                    echo "$e"; return 0
                fi
            done
            $DEBUG && log_debug "OK    exe padrão: ${exes[0]}" || true
            echo "${exes[0]}" ;;
    esac
}

find_linux_exe() {
    local i="$1" l="$2"
    local d="$l/steamapps/common/$i"
    [[ -d "$d" ]] || { $DEBUG && log_debug "LIN   diretório não encontrado: $d"; return 1; }
    local il="${i,,}" elfs=()
    while IFS= read -r -d '' f; do
        file -b "$f" 2>/dev/null | grep -qi "ELF.*executable" && elfs+=("$f")
    done < <(find "$d" -maxdepth 4 -type f ! -name '*.*' -print0 2>/dev/null)
    $DEBUG && log_debug "LIN   ${#elfs[@]} ELF encontrados em $i" || true

    local candidate=""
    for f in "${elfs[@]}"; do
        local fn; fn=$(basename "$f"); fn="${fn,,}"
        if [[ "$fn" == "$il" ]]; then
            candidate="$f"; break
        fi
    done
    if [[ -z "$candidate" ]]; then
        for f in "${elfs[@]}"; do
            local fn; fn=$(basename "$f"); fn="${fn,,}"
            if [[ "$fn" == *launcher* ]]; then
                candidate="$f"; break
            fi
        done
    fi
    if [[ -z "$candidate" ]]; then
        for f in "${elfs[@]}"; do
            if [[ -x "$f" ]]; then
                candidate="$f"; break
            fi
        done
    fi
    [[ -z "$candidate" ]] && candidate="${elfs[0]:-}"
    if [[ -n "$candidate" ]]; then
        $DEBUG && log_debug "OK    exe linux: $candidate" || true
        echo "$candidate"; return 0
    fi

    for s in "start.sh" "launch.sh" "run.sh" "game.sh" "${il}.sh"; do
        if [[ -f "$d/$s" ]]; then
            $DEBUG && log_debug "OK    shell script: $d/$s" || true
            echo "$d/$s"; return 0
        fi
    done
    $DEBUG && log_debug "FALHA nenhum executável linux para $i" || true
    return 1
}

get_platform_icon() {
    local i="$1" l="$2"
    local d="$l/steamapps/common/$i"
    [[ -d "$d" ]] || { echo "$ICON_WINDOWS"; return; }
    while IFS= read -r -d '' f; do
        file -b "$f" 2>/dev/null | grep -qi "ELF.*executable" && { echo "$ICON_LINUX"; return; }
    done < <(find "$d" -maxdepth 2 -type f ! -name '*.*' -print0 2>/dev/null)
    echo "$ICON_WINDOWS"
}

# ===============
# RUNTIME
# ===============

find_runtime() {
    for l in "${LIBRARIES[@]}"; do
        for r in "SteamLinuxRuntime_sniper" "SteamLinuxRuntime_4" "SteamLinuxRuntime"; do
            local b="$l/steamapps/common/$r/run"
            if [[ -x "$b" ]]; then
                $DEBUG && log_debug "OK    runtime: $b" || true
                echo "$b"; return 0
            fi
        done
    done
    $DEBUG && log_debug "FALHA runtime não encontrado" || true
    return 1
}

# ===============
# PROTON
# ===============

get_proton() {
    local a="$1" v="PROTON_${a}"
    if [[ -n "${!v:-}" ]]; then
        $DEBUG && log_debug "OK    proton por variável: ${!v}" || true
        echo "${!v}"; return
    fi
    if [[ -n "${PROTON_DEFAULT:-}" ]] && [[ -f "$PROTON_DEFAULT" ]]; then
        $DEBUG && log_debug "OK    proton default: $PROTON_DEFAULT" || true
        echo "$PROTON_DEFAULT"; return
    fi
    for l in "${LIBRARIES[@]}"; do
        local pd="$l/steamapps/common"
        [[ -d "$pd" ]] || continue
        while IFS= read -r -d '' p; do
            if [[ -x "$p" ]]; then
                $DEBUG && log_debug "OK    proton encontrado: $p" || true
                echo "$p"; return
            fi
        done < <(find "$pd" -maxdepth 3 -name 'proton' -type f -print0 2>/dev/null)
    done
    $DEBUG && log_debug "FALHA proton não encontrado para appid $a" || true
    echo ""
}

get_proton_label() {
    local p
    p=$(get_proton "$1")
    [[ -z "$p" ]] && { echo "Proton"; return; }
    basename "$(dirname "$p")"
}


# ===============
# LANÇAMENTO NATIVO
# ===============

launch_native() {
    local a="$1" n="$2" e="$3"
    local d
    d=$(dirname "$e")
    local p
    p=$(load_params "$a") || true
    apply_controller_mapping "$a"

    $DEBUG && log_debug "LAUNCH tentativa nativa: $n (appid $a)" || true

    local altered=false
    while IFS= read -r -d '' f; do
        if [[ ! -x "$f" ]]; then
            chmod +x "$f" 2>/dev/null || true
            altered=true
        fi
    done < <(find "$d" -maxdepth 4 -type f \( -executable -o -name '*launcher*' \) -print0 2>/dev/null)
    while IFS= read -r -d '' f; do
        if file -b "$f" 2>/dev/null | grep -qi "ELF.*executable"; then
            if [[ ! -x "$f" ]]; then
                chmod +x "$f" 2>/dev/null || true
                altered=true
            fi
        fi
    done < <(find "$d" -maxdepth 4 -type f ! -name '*.*' -print0 2>/dev/null)
    local libdir="$d/lib"
    if [[ -d "$libdir" ]] && [[ -n "$(find "$libdir" -type f ! -perm -o+w -print -quit 2>/dev/null)" ]]; then
        find "$libdir" -type f ! -perm -o+w -exec chmod +wx {} \; 2>/dev/null || true
        altered=true
    fi
    $altered && echo -e "  ${CHECK} permissões corrigidas"

    [[ -z "$e" ]] && {
        echo -e "  ${XIS} ${n} não tem binário nativo"
        $DEBUG && log_debug "FALHA nenhum binário nativo para $n" || true
        ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}" || true
        return
    }

    local b
    b=$(basename "$e")
    export SteamAppId="$a" SteamGameId="$a"

    if $DEBUG; then
        show_params_programs_status "$p" 
        log_debug "OK    binário: $e"
        if [[ -z "$p" ]]; then
            log_debug "OK    params: nenhum"
        else
            log_debug "OK    params: $p"
        fi
        check_deps32_status         
    fi

    $DEBUG && log_debug "LAUNCH tentativa direta: ./$b" || true
    exec_game "$d" "$b" "$p" "$DEBUG"
    GAME_PID=$!; loading_dots 1

    if kill -0 "$GAME_PID" 2>/dev/null; then
        echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
        echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
        $DEBUG && log_debug "OK    iniciado (pid: $GAME_PID)" || true
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
        $DEBUG && log_debug "OK    fechado (exit: $?)" || true
        GAME_PID=""; return
    fi
    wait "$GAME_PID" 2>/dev/null || true
    $DEBUG && log_debug "FALHA tentativa direta falhou" || true

    local rt
    rt=$(find_runtime) || true
    if [[ -n "$rt" ]]; then
        $DEBUG && log_debug "LAUNCH tentativa via runtime: $rt" || true
        if $DEBUG; then
            (cd "$d"; "$rt" -- eval "./$b" $p) &
        else
            (cd "$d"; "$rt" -- "./$b" $p &>/dev/null) &
        fi
        GAME_PID=$!; loading_dots 1
        if kill -0 "$GAME_PID" 2>/dev/null; then
            echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
            echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
            $DEBUG && log_debug "OK    iniciado via runtime (pid: $GAME_PID)" || true
            wait "$GAME_PID" 2>/dev/null || true
            echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
            $DEBUG && log_debug "OK    fechado via runtime (exit: $?)" || true
            GAME_PID=""; return
        fi
        wait "$GAME_PID" 2>/dev/null || true
        $DEBUG && log_debug "FALHA tentativa via runtime falhou" || true
    fi

    local rest=()
    while IFS= read -r -d '' f; do
        file -b "$f" 2>/dev/null | grep -qi "ELF.*executable" && [[ "$f" != "$e" ]] && rest+=("$f")
    done < <(find "$d" -maxdepth 2 -type f ! -name '*.*' -print0 2>/dev/null)

    if [[ ${#rest[@]} -gt 0 ]]; then
        local s="${rest[0]}" sn
        sn=$(basename "$s")
        $DEBUG && log_debug "LAUNCH tentativa alternativa: $sn" || true
        exec_game "$d" "$sn" "$p" "$DEBUG"
        GAME_PID=$!; loading_dots 1
        if kill -0 "$GAME_PID" 2>/dev/null; then
            echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (Nativo)"
            echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
            $DEBUG && log_debug "OK    iniciado via alternativa (pid: $GAME_PID)" || true
            wait "$GAME_PID" 2>/dev/null || true
            echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
            $DEBUG && log_debug "OK    fechado via alternativa (exit: $?)" || true
            GAME_PID=""; return
        fi
        wait "$GAME_PID" 2>/dev/null || true
        $DEBUG && log_debug "FALHA tentativa alternativa falhou" || true
    fi

    echo -e "  ${XIS} ${NEGRITO}${n}${NC} não iniciou"
    $DEBUG && log_debug "FALHA $n não iniciou (todas as tentativas falharam)" || true
    ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}" || true
    GAME_PID=""
}

# ===============
# LANÇAMENTO PROTON
# ===============

launch_proton() {
    local a="$1" n="$2" e="$3"
    local d
    d=$(dirname "$e")
    local p
    p=$(load_params "$a") || true
    apply_controller_mapping "$a"
    local pl
    pl=$(get_proton_label "$a")

    $DEBUG && log_debug "LAUNCH tentativa proton: $n (appid $a)" || true

    [[ -z "$e" ]] && {
        echo -e "  ${XIS} .exe não encontrado para ${NEGRITO}${n}${NC}"
        $DEBUG && log_debug "FALHA .exe não encontrado para ${n}" || true
        ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}" || true
        return
    }

    local pr
    pr=$(get_proton "$a")

    [[ -z "$pr" ]] || [[ ! -f "$pr" ]] && {
        echo -e "  ${XIS} Proton não encontrado para ${NEGRITO}${n}${NC}"
        echo -e "  ${CINZA}[INFO] configure ${CONFIG_DIR}/proton.conf${NC}"
        $DEBUG && log_debug "FALHA Proton não encontrado para ${a}" || true
        read -p "  Enter para voltar..."; return
    }

    local cd="${d%%/common/$i}/compatdata/$a"

    if $DEBUG; then
        log_debug "OK    .exe: $e"
        log_debug "OK    proton: $pr"
        log_debug "OK    compatdata: $cd"
        log_debug "OK    STEAM_HOME: $STEAM_HOME"
        show_params_programs_status "$p"
        check_deps32_status
    fi

    mkdir -p "$cd"
    export STEAM_COMPAT_DATA_PATH="$cd"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_HOME"
    export SteamAppId="$a" SteamGameId="$a"

    echo -e "  ${BOLINHO} ${NEGRITO}${n}${NC} (${pl})"
    $DEBUG && log_debug "LAUNCH executando proton: $pr run $e" || true

    local proton_cmd="\"$pr\" run \"$e\""
    if [[ -n "$p" ]]; then
        if [[ "$p" == *"%command%"* ]]; then
            proton_cmd="${p//%command%/$proton_cmd}"
        else
            proton_cmd="$proton_cmd $p"
        fi
    fi
    if $DEBUG; then
        eval "$proton_cmd" 2>&1 | grep -v -E '^gamemodeauto:' &
    else
        eval "$proton_cmd" &>/dev/null &
    fi
    GAME_PID=$!; loading_dots 1

    if kill -0 "$GAME_PID" 2>/dev/null; then
        echo -e "  ${CHECK} iniciado (pid: ${GAME_PID})"
        $DEBUG && log_debug "OK    iniciado via proton (pid: $GAME_PID)" || true
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${CINZA}[INFO] fechado (exit: $?)${NC}"
        $DEBUG && log_debug "OK    fechado via proton (exit: $?)" || true
    else
        wait "$GAME_PID" 2>/dev/null || true
        echo -e "  ${XIS} ${NEGRITO}${n}${NC} não iniciou via Proton"
        $DEBUG && log_debug "FALHA ${n} não iniciou via Proton" || true
        ! $DEBUG && echo -e "  ${CINZA}[INFO] use -d${NC}" || true
    fi
    GAME_PID=""
}

