#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
# ===============
# MENU DO JOGO
# ===============

show_game_menu() {
    local game="$1"
    IFS='|' read -r appid name installdir library _ _ _ <<< "$game"
    $DEBUG && log_debug "menu: $name (appid $appid)" || true

    local linux_exe="" win_exe="" has_native=false has_proton=false
    linux_exe=$(find_linux_exe "$installdir" "$library" 2>/dev/null) || true
    if [[ -n "$linux_exe" ]]; then
        has_native=true
    else
        win_exe=$(find_game_exe "$installdir" "$library" 2>/dev/null) || true
        local proton_bin
        proton_bin=$(get_proton "$appid") || true
        if [[ -n "$proton_bin" ]]; then
            has_proton=true
            $DEBUG && log_debug "[OK] proton encontrado: $proton_bin" || true
        else
            $DEBUG && log_debug "[ERROR] proton não encontrado" || true
        fi
    fi

    if $DEBUG; then
        local current_params
        current_params=$(load_params "$appid") || true
        log_debug "[OK] parâmetro atual: ${current_params}"

        local native mapping controller_support
        IFS='|' read -r native mapping <<< "$(controller_status "$appid")"
        if [[ "$native" == "yes" ]] || { [[ -n "$mapping" ]] && is_valid_mapping "$mapping"; }; then
            controller_support="on"
        else
            controller_support="off"
        fi
        log_debug "[OK] suporte a controle: $controller_support"
    fi

    local can_play=false
    { [[ $has_native == true ]] || [[ $has_proton == true ]]; } && can_play=true

    _draw_game_menu() {
        local sel="$1" allow_back="$2"
        local playtime playtime_fmt
        playtime=$(get_playtime "$appid")
        playtime_fmt=$(format_playtime "$playtime")
        render_logo
        box_top
        box_mid "$name"
        box_row_blank

        local play_label right right_width left left_padded line
        if $can_play; then
            play_label="Jogar"
            right="${ICON_TIME} ${playtime_fmt}  "
        else
            play_label="Jogar (Proton não configurado)"
            right="  "
        fi
        right_width=$(display_width "$right")
        left="  ${play_label}"
        left_padded=$(pad_to_width "$left" $((BOXW - right_width)))
        line="${left_padded}${right}"
        if (( sel == 0 )); then box_row_selected "$line"; else box_row "$line"; fi

        local items=("Controle" "Parâmetros" "Excluir")
        local idx=1 item
        for item in "${items[@]}"; do
            local is_danger=false label="$item"
            if [[ "$item" =~ $DANGER_ITEMS_REGEX ]]; then
                is_danger=true; label="[${item}]"
            fi
            if (( idx == sel )); then
                box_row_selected "  ${label}" "$is_danger"
            elif $is_danger; then
                box_row "  ${label}" "  ${VERMELHO_CLARO}${label}${NC}"
            else
                box_row "  ${item}"
            fi
            idx=$((idx+1))
        done
        box_bottom
        render_footer "$allow_back"
    }

    while true; do
        run_menu 4 _draw_game_menu true
        case "$MENU_RESULT" in
            BACK) return ;;
            0)
                if [[ $has_native == true ]]; then
                    launch_native "$appid" "$name" "$linux_exe"
                elif [[ $has_proton == true ]]; then
                    launch_proton "$appid" "$name" "$win_exe"
                fi
                auto_return_delay 1.5
                return ;;
            1) show_game_controller_menu "$appid" "$name" ;;
            2) edit_params "$appid" "$name" ;;
            3)
                if confirm_dialog "Excluir" "Excluir ${name}?"; then
                    $DEBUG && log_debug "[OK] removendo jogo: $name (appid $appid)" || true
                    loading_dots 3 "Removendo ${name}"
                    rm -rf "$library/steamapps/common/$installdir" 2>/dev/null || true
                    rm -f "$library/steamapps/appmanifest_${appid}.acf" 2>/dev/null || true
                    rm -rf "$library/steamapps/compatdata/$appid" 2>/dev/null || true
                    ui_log "${CHECK} ${name} removido"
                    local remaining=()
                    for game_entry in "${GAMES[@]}"; do
                        IFS='|' read -r entry_appid _ _ _ _ <<< "$game_entry"
                        [[ "$entry_appid" != "$appid" ]] && remaining+=("$game_entry")
                    done
                    GAMES=("${remaining[@]}")
                    auto_return_delay 1.2
                    return
                fi ;;
        esac
    done
}

# ===============
# MENU DE MAPEAMENTO (POR JOGO)
# ===============

show_game_controller_menu() {
    local appid="$1" name="$2"

    _draw_game_controller_menu() {
        local sel="$1" allow_back="$2"
        local native="" mapping="" status_label status_icon
        IFS='|' read -r native mapping <<< "$(controller_status "$appid")"
        if [[ "$native" == "yes" ]]; then
            status_label="suporte nativo"; status_icon="$ICON_GAMEPAD"
        elif [[ -n "$mapping" ]] && is_valid_mapping "$mapping"; then
            status_label="config manual"; status_icon="$ICON_GAMEPAD"
        else
            status_label="teclado"; status_icon="$ICON_KEYBOARD"
        fi

        render_logo
        box_top
        box_mid "Controle"
        local name_display
        name_display=$(truncate_name "$name" $((BOXW - 6)))
        box_row "  ${name_display}" "  ${NEGRITO}${name_display}${NC}"
        box_row "  Status: ${status_label} ${status_icon}"
        box_row_blank
        local items=()
        if [[ "$native" == "yes" ]]; then
            items+=("Desmarcar suporte nativo")
        else
            items+=("Marcar suporte nativo")
        fi
        items+=("Configurar mapeamento" "Resetar")
        box_items "$sel" "${items[@]}"
        box_bottom
        render_footer "$allow_back"
    }

    while true; do
        run_menu 3 _draw_game_controller_menu true
        [[ "$MENU_RESULT" == "BACK" ]] && return

        local native="" mapping=""
        IFS='|' read -r native mapping <<< "$(controller_status "$appid")"
        case "$MENU_RESULT" in
            0)
                if [[ "$native" == "yes" ]]; then
                    loading_dots 1 "Desmarcar suporte nativo"
                    set_controller_native "$appid" "no" || true
                    $DEBUG && log_debug "[OK] suporte nativo desmarcado (appid $appid)" || true
                    ui_log "${CHECK} suporte nativo desmarcado"
                else
                    loading_dots 1 "Marcar suporte nativo"
                    set_controller_native "$appid" "yes" || true
                    $DEBUG && log_debug "[OK] suporte nativo marcado (appid $appid)" || true
                    ui_log "${CHECK} suporte nativo marcado"
                fi
                auto_return_delay 1.2 ;;
            1)
                $DEBUG && log_debug "[OK] iniciando configuração de mapeamento (appid $appid)" || true
                if gamepad_tool_installed; then
                    gamepad_tool_run_and_capture "$mapping" || true
                else
                    input_sdl_mapping "$mapping" || true
                fi
                local new_mapping="$INPUT_RESULT"
                if [[ -n "$new_mapping" ]]; then
                    set_controller_mapping "$appid" "$new_mapping" || true
                    ui_log "${CHECK} mapeamento salvo"
                fi
                auto_return_delay 1.2 ;;
            2)
                reset_controller_override "$appid" || true
                ui_log "${CHECK} configurações resetadas"
                auto_return_delay 1.2 ;;
        esac
    done
}

# ===============
# MENU DE CONTROLES (GLOBAL)
# ===============

_controller_device_items() {
    CD_ITEMS=()
    local tool_installed=false
    gamepad_tool_installed && tool_installed=true
    if $tool_installed; then
        CD_ITEMS+=("Configurar mapeamento geral")
    else
        CD_ITEMS+=("Baixar gamepad-tool")
    fi
    if $tool_installed && [[ -n "$GAMEPAD_TOOL_UPDATE_AVAILABLE" ]]; then
        CD_ITEMS+=("Atualização disponível (v${GAMEPAD_TOOL_UPDATE_AVAILABLE})")
    fi
    CD_ITEMS+=("Resetar")
    if $tool_installed; then
        CD_ITEMS+=("Remover gamepad-tool")
    fi
}

show_controller_device_menu() {
    local device_name="$1"

    _draw_controller_device_menu() {
        local sel="$1" allow_back="$2"
        _controller_device_items
        local global_mapping=""
        [[ -f "$CONTROLLER_GLOBAL_CONF" ]] && global_mapping=$(cat "$CONTROLLER_GLOBAL_CONF" || true)

        render_logo
        box_top
        box_mid "$device_name"
        if [[ -n "$global_mapping" ]] && is_valid_mapping "$global_mapping"; then
            box_row "  Status: mapeamento ativo"
        else
            box_row "  Status: sem mapeamento"
        fi
        box_row_blank
        box_items "$sel" "${CD_ITEMS[@]}"
        box_bottom
        render_footer "$allow_back"
    }

    while true; do
        gamepad_tool_check_update
        _controller_device_items
        run_menu "${#CD_ITEMS[@]}" _draw_controller_device_menu true
        [[ "$MENU_RESULT" == "BACK" ]] && return

        local chosen="${CD_ITEMS[$MENU_RESULT]}"
        case "$chosen" in
            "Configurar mapeamento geral")
                $DEBUG && log_debug "[OK] configurando mapeamento geral" || true
                local global_mapping=""
                [[ -f "$CONTROLLER_GLOBAL_CONF" ]] && global_mapping=$(cat "$CONTROLLER_GLOBAL_CONF" || true)
                gamepad_tool_run_and_capture "$global_mapping" || true
                local new_mapping="$INPUT_RESULT"
                if [[ -n "$new_mapping" ]]; then
                    echo "$new_mapping" > "$CONTROLLER_GLOBAL_CONF" || true
                    $DEBUG && log_debug "[OK] mapeamento geral salvo" || true
                    ui_log "${CHECK} mapeamento geral salvo"
                fi
                auto_return_delay 1.2 ;;
            "Baixar gamepad-tool")
                gamepad_tool_download || true
                auto_return_delay 1.2 ;;
            "Resetar")
                rm -f "$CONTROLLER_GLOBAL_CONF" || true
                $DEBUG && log_debug "[OK] mapeamento geral resetado" || true
                ui_log "${CHECK} mapeamento geral resetado"
                auto_return_delay 1.2 ;;
            "Remover gamepad-tool")
                if confirm_dialog "gamepad-tool" "Remover gamepad-tool?"; then
                    gamepad_tool_remove
                    ui_log "${CHECK} gamepad-tool removido"
                    auto_return_delay 1.2
                fi ;;
            "Atualização disponível"*)
                gamepad_tool_download || true
                auto_return_delay 1.2 ;;
        esac
    done
}

show_controllers_menu() {
    local devices=()
    mapfile -t devices < <(detect_controllers)

    gamepad_tool_check_update

    _draw_controllers_menu() {
        local sel="$1" allow_back="$2"
        render_logo
        box_top
        box_mid "Controles"
        box_row_blank
        if [[ ${#devices[@]} -eq 0 ]]; then
            box_row "  nenhum controle detectado"
        else
            box_items "$sel" "${devices[@]}"
        fi
        box_bottom
        render_footer "$allow_back"
    }

    if [[ ${#devices[@]} -eq 0 ]]; then
        run_menu 0 _draw_controllers_menu true
        return
    fi

    while true; do
        run_menu "${#devices[@]}" _draw_controllers_menu true
        [[ "$MENU_RESULT" == "BACK" ]] && return
        show_controller_device_menu "${devices[$MENU_RESULT]}"
    done
}

# ===============
# LOJA
# ===============

show_store_menu() {
    _draw_store_menu() {
        local sel="$1" allow_back="$2"
        render_logo
        box_top
        box_mid "Loja"
        box_row_blank
        box_items "$sel" "Baixar jogos"
        box_bottom
        render_footer "$allow_back"
    }

    while true; do
        run_menu 1 _draw_store_menu true
        case "$MENU_RESULT" in
            BACK) return ;;
            0) $DEBUG && log_debug "[OK] acessando baixar jogos"; baixar_jogos; scan_games; filter_games ;;
        esac
    done
}

# ===============
# BIBLIOTECA
# ===============

LIBRARY_VISIBLE=0

_library_visible_count() {
    local term_height visible
    term_height=$(get_term_height)
    visible=$(( term_height - $(chrome_lines_scrollable) - 1 ))
    (( visible < 3 )) && visible=3
    (( visible > 14 )) && visible=14
    echo "$visible"
}

show_library_menu() {
    if [[ ${#GAMES[@]} -eq 0 ]]; then return; fi

    local allow_back=true search_mode=false search_query="" sel=0 window_start=0 LIBRARY_DONE=false
    local -a FILTERED_INDICES=()

    _library_filter_indices() {
        local query="${1,,}" idx name
        FILTERED_INDICES=()
        for (( idx=0; idx<${#GAMES[@]}; idx++ )); do
            IFS='|' read -r _ name _ _ _ _ _ <<< "${GAMES[$idx]}"
            if [[ -z "$query" ]] || [[ "${name,,}" == *"$query"* ]]; then
                FILTERED_INDICES+=("$idx")
            fi
        done
    }
    _library_filter_indices ""

    _library_open_selected() {
        local total=${#FILTERED_INDICES[@]}
        (( total == 0 )) && return
        local chosen_idx="${FILTERED_INDICES[$sel]}"
        show_game_menu "${GAMES[$chosen_idx]}"
        scan_games || true
        filter_games || true
        if [[ ${#GAMES[@]} -eq 0 ]]; then 
            LIBRARY_DONE=true
            return
        fi
        _library_filter_indices "$search_query"
        local new_total=${#FILTERED_INDICES[@]}
        (( sel >= new_total )) && sel=$(( new_total - 1 ))
        (( sel < 0 )) && sel=0
        return 0
    }

    _draw_library_menu() {
        render_logo
        box_top
        box_mid "Biblioteca"
        local total=${#FILTERED_INDICES[@]}
        local start=$window_start
        if (( start > 0 )); then
            box_row "  ${CINZA}▲ mais acima${NC}"
        else
            box_row_blank
        fi
        local i list_idx real_idx game appid name installdir library native mapping icon platform display_name
        local right right_width name_max left left_padded line
        for (( i=0; i<LIBRARY_VISIBLE; i++ )); do
            list_idx=$(( start + i ))
            if (( list_idx >= total )); then
                box_row_blank
                continue
            fi
            real_idx="${FILTERED_INDICES[$list_idx]}"
            game="${GAMES[$real_idx]}"
            IFS='|' read -r appid name installdir library platform _ <<< "$game"
            IFS='|' read -r native mapping <<< "$(controller_status "$appid")"
            if [[ "$native" == "yes" ]] || { [[ -n "$mapping" ]] && is_valid_mapping "$mapping"; }; then
                icon="$ICON_GAMEPAD"
            else
                icon="$ICON_KEYBOARD"
            fi
            local platform_icon=$([ "$platform" = "linux" ] && echo "$ICON_LINUX" || echo "$ICON_WINDOWS")
            right="${icon}  ${platform_icon}  "
            right_width=$(display_width "$right")
            name_max=$(( BOXW - right_width - 4 ))
            (( name_max < 8 )) && name_max=8
            display_name=$(truncate_name "$name" "$name_max")
            left="  ${display_name}"
            left_padded=$(pad_to_width "$left" $((BOXW - right_width)))
            line="${left_padded}${right}"
            if (( list_idx == sel )); then box_row_selected "$line"; else box_row "$line"; fi
        done
        if (( total == 0 )); then
            box_row "  ${CINZA}nenhum resultado${NC}"
        elif (( start + LIBRARY_VISIBLE < total )); then
            box_row "  ${CINZA}▼ mais abaixo${NC}"
        else
            box_row_blank
        fi
        box_bottom
        render_footer "$allow_back"
        box_row_search "$search_query" "$search_mode"
    }

    while true; do
        local dirty=true

        while true; do
            if $dirty; then
                wait_for_resize
                RESIZED=0
                box_init
                LIBRARY_VISIBLE=$(_library_visible_count)
                FRAME_LINES=0
                local content
                content=$(_draw_library_menu)
                render_static_screen "$content"
                dirty=false
            fi

            local total=${#FILTERED_INDICES[@]} action

            if $search_mode; then
                action=$(_read_library_search_key)
                case "$action" in
                    RESIZE) dirty=true ;;
                    IDLE|IGNORE) : ;;
                    UP)   (( total > 0 )) && { sel=$(( (sel - 1 + total) % total )); dirty=true; } ;;
                    DOWN) (( total > 0 )) && { sel=$(( (sel + 1) % total )); dirty=true; } ;;
                    LEFT)
                        search_mode=false
                        search_query=""
                        _library_filter_indices ""
                        sel=0
                        dirty=true ;;
                    BACKSPACE)
                        search_query="${search_query%?}"
                        _library_filter_indices "$search_query"
                        sel=0
                        dirty=true ;;
                    CHAR:/)
                        search_mode=false
                        dirty=true ;;
                    CHAR:*)
                        local new_char="${action#CHAR:}"
                        if _is_safe_char "$new_char"; then
                            search_query+="$new_char"
                            _library_filter_indices "$search_query"
                            sel=0
                            dirty=true
                        fi ;;
                    ENTER) _library_open_selected; $LIBRARY_DONE && return; dirty=true ;;
                esac
            else
                action=$(read_key)
                case "$action" in
                    RESIZE) dirty=true ;;
                    IDLE) : ;;
                    UP)   (( total > 0 )) && { sel=$(( (sel - 1 + total) % total )); dirty=true; } ;;
                    DOWN) (( total > 0 )) && { sel=$(( (sel + 1) % total )); dirty=true; } ;;
                    LEFT) return ;;
                    CHAR:/)
                        search_mode=true
                        dirty=true ;;
                    CHAR:q|CHAR:Q)
                        prompt_exit_steam
                        clear
                        tput cnorm 2>/dev/null || true
                        exit 0 ;;
                    ENTER|RIGHT) 
                    _library_open_selected
                    while IFS= read -rsn1 -t 0.001 _ 2>/dev/null; do :; done
                    $LIBRARY_DONE && return
                    dirty=true 
                    ;;
                esac
            fi

            total=${#FILTERED_INDICES[@]}
            (( total > 0 && sel >= total )) && sel=$(( total - 1 ))
            (( sel < 0 )) && sel=0
            if (( total > 0 && LIBRARY_VISIBLE > 0 && total > LIBRARY_VISIBLE )); then
                (( sel < window_start && dirty )) && window_start=$sel
                (( sel >= window_start + LIBRARY_VISIBLE && dirty )) && window_start=$(( sel - LIBRARY_VISIBLE + 1 ))
            else
                window_start=0
            fi
        done
    done
}

# ===============
# CONFIG
# ===============

show_config_menu() {
    _draw_config_menu() {
        local sel="$1" allow_back="$2"
        render_logo
        box_top
        box_mid "Config"
        box_row_blank
        box_items "$sel" "Controle" "Dependências"
        box_bottom
        render_footer "$allow_back"
    }

    while true; do
        run_menu 2 _draw_config_menu true
        case "$MENU_RESULT" in
            BACK) return ;;
            0) show_controllers_menu ;;
            1) show_deps_menu ;;
        esac
    done
}

# ===============
# MENU PRINCIPAL
# ===============

show_main_menu() {
    check_update "$@"
    tput civis 2>/dev/null || true

    while true; do
        local has_games=true
        (( ${#GAMES[@]} == 0 )) && has_games=false

        local sections=("Loja")
        $has_games && sections+=("Biblioteca")
        sections+=("Config")

        _draw_main_menu() {
            local sel="$1" allow_back="$2"
            render_logo
            box_top
            box_mid "v${VERSION} ${AGL}"
            box_row_blank
            box_items "$sel" "${sections[@]}"
            box_bottom
            render_footer "$allow_back"
        }

        run_menu "${#sections[@]}" _draw_main_menu false

        local choice="${sections[$MENU_RESULT]}"
        case "$choice" in
            "Loja") $DEBUG && log_debug "[OK] acessando loja"; show_store_menu ;;
            "Biblioteca") $DEBUG && log_debug "[OK] acessando biblioteca"; show_library_menu ;;
            "Config") $DEBUG && log_debug "[OK] acessando config"; show_config_menu ;;
        esac
    done
}