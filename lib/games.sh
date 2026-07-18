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
    local installdir="$1" library="$2"
    local dir="$library/steamapps/common/$installdir"
    [[ -d "$dir" ]] || { $DEBUG && log_debug "[ERROR] diretório não encontrado: $dir"; return 1; }
    local exes=()
    while IFS= read -r -d '' exe; do
        local base=$(basename "$exe"); base="${base,,}"
        case "$base" in
            uninstall*|unins*|*redist*|vcredist*|dxwebsetup*|dotnet*|*setup*) continue ;;
        esac
        exes+=("$exe")
    done < <(find "$dir" -maxdepth 4 -name '*.exe' -type f -print0 2>/dev/null)
    case ${#exes[@]} in
        0) return 1 ;;
        1) $DEBUG && log_debug "[OK] exe selecionado: ${exes[0]}"; echo "${exes[0]}" ;;
        *)
            local installdir_lower="${installdir,,}"
            for exe in "${exes[@]}"; do
                local exe_name; exe_name=$(basename "$exe" .exe); exe_name="${exe_name,,}"
                if [[ "$exe_name" == "$installdir_lower" ]]; then
                    $DEBUG && log_debug "[OK] exe selecionado: $exe" || true
                    echo "$exe"; return 0
                fi
            done
            $DEBUG && log_debug "[OK] exe selecionado: ${exes[0]}" || true
            echo "${exes[0]}" ;;
    esac
}

find_linux_exe() {
    local installdir="$1" library="$2"
    local dir="$library/steamapps/common/$installdir"
    [[ -d "$dir" ]] || { $DEBUG && log_debug "[ERROR] diretório não encontrado: $dir"; return 1; }
    local installdir_lower="${installdir,,}" elfs=()
    local depth candidates=()
    for depth in 1 2 4; do
        candidates=()
        while IFS= read -r -d '' file_path; do
            case "${file_path,,}" in
                *.dll|*.so|*.so.*|*.dat|*.rgssad|*.ini|*.txt|*.png|*.cfg|*.conf) continue ;;
            esac
            candidates+=("$file_path")
        done < <(find "$dir" -maxdepth "$depth" -type f -print0 2>/dev/null)

        if (( ${#candidates[@]} > 0 )); then
            local file_output i=0 desc
            file_output=$(file -b -- "${candidates[@]}" 2>/dev/null)
            elfs=()
            while IFS= read -r desc; do
                [[ "$desc" =~ ELF.*executable ]] && elfs+=("${candidates[$i]}")
                i=$((i+1))
            done <<< "$file_output"
        fi
        (( ${#elfs[@]} > 0 )) && break
    done
    local candidate=""
    for elf in "${elfs[@]}"; do
        local elf_name; elf_name=$(basename "$elf"); elf_name="${elf_name,,}"
        if [[ "$elf_name" == "$installdir_lower" ]]; then
            candidate="$elf"; break
        fi
    done
    if [[ -z "$candidate" ]]; then
        for elf in "${elfs[@]}"; do
            local elf_name; elf_name=$(basename "$elf"); elf_name="${elf_name,,}"
            if [[ "$elf_name" == *launcher* ]]; then
                candidate="$elf"; break
            fi
        done
    fi
    if [[ -z "$candidate" ]]; then
        for elf in "${elfs[@]}"; do
            local elf_name; elf_name=$(basename "$elf"); elf_name="${elf_name,,}"
            if [[ "$elf_name" == *x86_64* ]] || [[ "$elf_name" == *amd64* ]]; then
                candidate="$elf"; break
            fi
        done
    fi
    if [[ -z "$candidate" ]]; then
        for elf in "${elfs[@]}"; do
            if [[ -x "$elf" ]]; then
                candidate="$elf"; break
            fi
        done
    fi
    [[ -z "$candidate" ]] && candidate="${elfs[0]:-}"
    if [[ -n "$candidate" ]]; then
        $DEBUG && log_debug "[OK] exe linux: $candidate" || true
        echo "$candidate"; return 0
    fi

    for script in "start.sh" "launch.sh" "run.sh" "game.sh" "${installdir_lower}.sh"; do
        if [[ -f "$dir/$script" ]]; then
            $DEBUG && log_debug "[OK] shell script: $dir/$script" || true
            echo "$dir/$script"; return 0
        fi
    done
    return 1
}

# ===============
# RUNTIME
# ===============

find_runtime() {
    for library in "${LIBRARIES[@]}"; do
        local scout_dir="$library/steamapps/common/SteamLinuxRuntime"
        local scout_bin="$scout_dir/scout-on-soldier-entry-point-v2"
        if [[ -x "$scout_bin" ]]; then
            echo "$scout_bin"
            $DEBUG && log_debug "[OK] runtime: $scout_bin" || true
            return 0
        fi
        for runtime_name in "SteamLinuxRuntime_sniper" "SteamLinuxRuntime_4"; do
            local bin="$library/steamapps/common/$runtime_name/run"
            if [[ -x "$bin" ]]; then
                echo "$bin"
                $DEBUG && log_debug "[OK] runtime: $bin" || true
                return 0
            fi
        done
    done
    $DEBUG && log_debug "[ERROR] runtime não encontrado" || true
    return 1
}

# ===============
# PROTON
# ===============

PROTON_BIN_CACHE=""
PROTON_BIN_CACHE_SET=false

get_proton() {
    local appid="$1" var="PROTON_${appid}"
    if [[ -n "${!var:-}" ]]; then
        echo "${!var}"; return
    fi
    if [[ -n "${PROTON_DEFAULT:-}" ]] && [[ -f "$PROTON_DEFAULT" ]]; then
        echo "$PROTON_DEFAULT"; return
    fi
    if $PROTON_BIN_CACHE_SET; then
        echo "$PROTON_BIN_CACHE"; return
    fi
    for library in "${LIBRARIES[@]}"; do
        local common_dir="$library/steamapps/common"
        [[ -d "$common_dir" ]] || continue
        while IFS= read -r -d '' proton_bin; do
            if [[ -x "$proton_bin" ]]; then
                PROTON_BIN_CACHE="$proton_bin"; PROTON_BIN_CACHE_SET=true
                echo "$proton_bin"; return
            fi
        done < <(find "$common_dir" -maxdepth 3 -name 'proton' -type f -print0 2>/dev/null)
    done
    PROTON_BIN_CACHE=""; PROTON_BIN_CACHE_SET=true
    echo ""
}

get_proton_label() {
    local proton_path
    proton_path=$(get_proton "$1")
    [[ -z "$proton_path" ]] && { echo "Proton"; return; }
    basename "$(dirname "$proton_path")"
}

# ===============
# HISTÓRICO PRÓPRIO
# ===============

mark_played() {
    mkdir -p "$CONFIG_DIR/lastplayed"
    date +%s > "$CONFIG_DIR/lastplayed/$1"
}

# ===============
# LANÇAMENTO NATIVO
# ===============

_launch_native_wait() {
    local name="$1" pid="$2" via="$3"
    status_box_add "${BOLINHO} ${name} (Nativo)"
    status_box_add "${CHECK} iniciado (pid: ${pid})"
    $DEBUG && log_debug "[OK] iniciado ${via} (pid: $pid)" || true

    local frames=("." ".." "...") i=0
    while kill -0 "$pid" 2>/dev/null; do
        ui_log "Executando jogo ${frames[$((i % 3))]}"
        sleep 0.5
        i=$((i + 1))
    done

    ui_log_clear
    loading_dots 2 "Retornando à biblioteca"
    $DEBUG && log_debug "[OK] fechado ${via}" || true
}

launch_native() {
    local appid="$1" name="$2" exe="$3"
    local dir
    dir=$(dirname "$exe")
    local params
    params=$(load_params "$appid") || true
    apply_controller_mapping "$appid"

    status_box_start "$name"
    $DEBUG && log_debug "[OK] jogo iniciado: tentativa nativa para $name (appid $appid)" || true

    local altered=false
    while IFS= read -r -d '' file_path; do
        if [[ ! -x "$file_path" ]]; then
            chmod +x "$file_path" 2>/dev/null || true
            altered=true
        fi
    done < <(find "$dir" -maxdepth 4 -type f \( -executable -o -name '*launcher*' \) -print0 2>/dev/null)
    while IFS= read -r -d '' file_path; do
        if file -b "$file_path" 2>/dev/null | grep -qi "ELF.*executable"; then
            if [[ ! -x "$file_path" ]]; then
                chmod +x "$file_path" 2>/dev/null || true
                altered=true
            fi
        fi
    done < <(find "$dir" -maxdepth 4 -type f ! -name '*.*' -print0 2>/dev/null)
    local libdir="$dir/lib"
    if [[ -d "$libdir" ]] && [[ -n "$(find "$libdir" -type f ! -perm -o+w -print -quit 2>/dev/null)" ]]; then
        find "$libdir" -type f ! -perm -o+w -exec chmod +wx {} \; 2>/dev/null || true
        altered=true
    fi
    $DEBUG && $altered && status_box_add "${CHECK} permissões corrigidas"

    [[ -z "$exe" ]] && {
        status_box_add "${XIS} ${name} não tem binário nativo"
        $DEBUG && log_debug "[ERROR] nenhum binário nativo para $name" || true
        ! $DEBUG && status_box_add "${CINZA}[INFO] use -d${NC}" || true
        return
    }

    local exe_name
    exe_name=$(basename "$exe")
    export SteamAppId="$appid" SteamGameId="$appid"

    if $DEBUG; then
        show_params_programs_status "$params"
        log_debug "[OK] binário: $exe"
        if [[ -z "$params" ]]; then
            log_debug "[OK] params: nenhum"
        else
            log_debug "[OK] params: $params"
        fi
        check_deps32_status
    fi

    local skip_runtime=false rt_id
    for rt_id in "${RUNTIME_INCOMPATIBLE_APPIDS[@]}"; do
        [[ "$rt_id" == "$appid" ]] && { skip_runtime=true; break; }
    done

    local runtime
    runtime=$(find_runtime) || true
    if [[ -n "$runtime" ]] && ! $skip_runtime; then
        $DEBUG && log_debug "[OK] tentativa via runtime: $runtime" || true
        $DEBUG && status_box_add "tentando via runtime .."
        local runtime_cmd
        if [[ "$params" == *"%command%"* ]]; then
            runtime_cmd="${params//%command%/./$exe_name}"
        else
            runtime_cmd="$params ./$exe_name"
        fi
        if $DEBUG; then
            (cd "$dir"; "$runtime" -- bash -c "$runtime_cmd" 2>&1 | grep -v -E '^gamemodeauto:') &
        else
            (cd "$dir"; "$runtime" -- bash -c "$runtime_cmd" &>/dev/null) &
        fi
        GAME_PID=$!; loading_dots 1 "Aguardando"
        if kill -0 "$GAME_PID" 2>/dev/null; then
            mark_played "$appid"
            _launch_native_wait "$name" "$GAME_PID" "via runtime"
            GAME_PID=""; return
        fi
        wait "$GAME_PID" 2>/dev/null || true
        $DEBUG && log_debug "[ERROR] tentativa via runtime falhou" || true
    fi

    $DEBUG && log_debug "[OK] tentativa direta: ./$exe_name" || true
    $DEBUG && status_box_add "tentando iniciar (nativo) .."
    exec_game "$dir" "$exe_name" "$params" "$DEBUG"
    GAME_PID=$!; loading_dots 1 "Aguardando"

    if kill -0 "$GAME_PID" 2>/dev/null; then
        mark_played "$appid"
        _launch_native_wait "$name" "$GAME_PID" "direto"
        GAME_PID=""; return
    fi
    wait "$GAME_PID" 2>/dev/null || true
    $DEBUG && log_debug "[ERROR] tentativa direta falhou" || true

    local fallback_bins=()
    while IFS= read -r -d '' file_path; do
        file -b "$file_path" 2>/dev/null | grep -qi "ELF.*executable" && [[ "$file_path" != "$exe" ]] && fallback_bins+=("$file_path")
    done < <(find "$dir" -maxdepth 2 -type f ! -name '*.*' -print0 2>/dev/null)

    if [[ ${#fallback_bins[@]} -gt 0 ]]; then
        local fallback="${fallback_bins[0]}" fallback_name
        fallback_name=$(basename "$fallback")
        $DEBUG && log_debug "[OK] tentativa alternativa: $fallback_name" || true
        $DEBUG && status_box_add "tentando alternativa: ${fallback_name} .."
        exec_game "$dir" "$fallback_name" "$params" "$DEBUG"
        GAME_PID=$!; loading_dots 1 "Aguardando"
        if kill -0 "$GAME_PID" 2>/dev/null; then
            mark_played "$appid"
            _launch_native_wait "$name" "$GAME_PID" "via alternativa"
            GAME_PID=""; return
        fi
        wait "$GAME_PID" 2>/dev/null || true
        $DEBUG && log_debug "[ERROR] tentativa alternativa falhou" || true
    fi

    status_box_add "${XIS} ${name} não iniciou"
    $DEBUG && log_debug "[ERROR] $name não iniciou (todas as tentativas falharam)" || true
    ! $DEBUG && status_box_add "${CINZA}[INFO] use -d${NC}" || true
    GAME_PID=""
}

# ===============
# LANÇAMENTO PROTON
# ===============

launch_proton() {
    local appid="$1" name="$2" exe="$3"
    local dir; dir=$(dirname "$exe")
    local params; params=$(load_params "$appid") || true
    apply_controller_mapping "$appid"
    local proton_label; proton_label=$(get_proton_label "$appid")

    status_box_start "$name"
    [[ -z "$exe" ]] && { status_box_add "${XIS} .exe não encontrado"; return; }

    local proton_bin; proton_bin=$(get_proton "$appid")
    [[ -z "$proton_bin" ]] || [[ ! -f "$proton_bin" ]] && { status_box_add "${XIS} Proton não encontrado"; return; }

    local library_root="${dir%%/steamapps/common/*}"
    local compat_data_dir="$library_root/steamapps/compatdata/$appid"

    mkdir -p "$compat_data_dir"
    export STEAM_COMPAT_DATA_PATH="$compat_data_dir"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_HOME"
    export SteamAppId="$appid" SteamGameId="$appid"

    status_box_add "${BOLINHO} ${name} (${proton_label})"
    local proton_cmd="\"$proton_bin\" run \"$exe\""
    [[ -n "$params" ]] && proton_cmd="${params//%command%/$proton_cmd}"

    if $DEBUG; then eval "$proton_cmd" 2>&1 | grep -v -E '^gamemodeauto:' &
    else eval "$proton_cmd" &>/dev/null & fi

    GAME_PID=$!; loading_dots 2 "Aguardando"

    if kill -0 "$GAME_PID" 2>/dev/null; then
        status_box_add "${CHECK} iniciado (pid: ${GAME_PID})"
        mark_played "$appid"

        while kill -0 "$GAME_PID" 2>/dev/null; do
            sleep 2
        done

        loading_dots 2 "Retornando à biblioteca"
    else
        status_box_add "${XIS} não iniciou via Proton"
    fi
    GAME_PID=""
}