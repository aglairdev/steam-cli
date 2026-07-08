#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
# ===============
# MENU DO JOGO
# ===============

show_game_menu() {
    local game="$1"
    IFS='|' read -r a n i l _ _ _ <<< "$game"
    $DEBUG && log_debug "OK    menu: $n (appid $a)" || true

    local linux_exe="" win_exe="" hn=false hp=false
    linux_exe=$(find_linux_exe "$i" "$l" 2>/dev/null) || true
    if [[ -n "$linux_exe" ]]; then
        hn=true
    else
        win_exe=$(find_game_exe "$i" "$l" 2>/dev/null) || true
        get_proton "$a" &>/dev/null && hp=true || hp=false
    fi

    while true; do
        local pt
        pt=$(get_playtime "$a")
        clear
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-tui ${AGL}${NC}"
        box_top
        box_mid "$n"
        local pt_fmt
        pt_fmt=$(format_playtime "$pt")
        if [[ $hn == true ]] || [[ $hp == true ]]; then
            box_row "  [1]  Jogar ${ICON_TIME} ${pt_fmt}" "  [${VERDE}1${NC}]  Jogar ${ICON_TIME} ${pt_fmt}"
        else
            box_row "  [!]  Jogar (Proton não configurado)" "  [${VERMELHO}!${NC}]  Jogar (Proton não configurado)"
        fi
        box_row "  [2]  Controle" "  [${AMARELO}2${NC}]  Controle"
        box_row "  [3]  Parâmetros" "  [${AMARELO}3${NC}]  Parâmetros"
        box_row "  [4]  Excluir" "  [${VERMELHO}4${NC}]  Excluir"
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        debug_flush
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
            show_game_controller_menu "$a" "$n"
        elif [[ "$c" == "3" ]]; then
            edit_params "$a" "$n"
        elif [[ "$c" == "4" ]]; then
            echo ""
            echo -e "  Excluir ${NEGRITO}${n}${NC}? (s/N)"
            read -p " > " resp
            case "${resp,,}" in
                s|sim)
                    $DEBUG && log_debug "OK    removendo jogo: $n (appid $a)" || true
                    echo -e "  ${CINZA}[INFO] removendo ${n} ..${NC}"
                    rm -rf "$l/steamapps/common/$i" 2>/dev/null || true
                    rm -f "$l/steamapps/appmanifest_${a}.acf" 2>/dev/null || true
                    rm -rf "$l/steamapps/compatdata/$a" 2>/dev/null || true
                    echo -e "  ${CHECK} ${n} removido"
                    local ng=()
                    for g in "${GAMES[@]}"; do
                        IFS='|' read -r ga _ _ _ _ <<< "$g"
                        [[ "$ga" != "$a" ]] && ng+=("$g")
                    done
                    GAMES=("${ng[@]}"); sleep 1; return ; true ;;
            esac
        elif [[ "$c" == "0" ]]; then
            return
        else
            invalid_option
        fi
    done
}

# ===============
# MENU DE MAPEAMENTO (POR JOGO)
# ===============

show_game_controller_menu() {
    local a="$1" n="$2"
    while true; do
        local native="" mapping="" status_label status_icon
        IFS='|' read -r native mapping <<< "$(controller_status "$a")"
        if [[ "$native" == "yes" ]]; then
            status_label="suporte nativo"; status_icon="$ICON_GAMEPAD"
        elif [[ -n "$mapping" ]] && is_valid_mapping "$mapping"; then
            status_label="config manual"; status_icon="$ICON_GAMEPAD"
        else
            status_label="teclado"; status_icon="$ICON_KEYBOARD"
        fi

        clear
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-tui ${AGL}${NC}"
        box_top
        box_mid "Controle"
        box_row "  ${n}" "  ${NEGRITO}${n}${NC}"
        box_row "  Status: ${status_icon}" "  Status: ${NEGRITO}${status_icon}${NC}"
        box_row ""
        if [[ "$native" == "yes" ]]; then
            box_row "  [1]  Desmarcar suporte nativo" "  [${VERMELHO}1${NC}]  Desmarcar suporte nativo"
        else
            box_row "  [1]  Marcar suporte nativo" "  [${VERDE}1${NC}]  Marcar suporte nativo"
        fi
        box_row "  [2]  Configurar mapeamento" "  [${AMARELO}2${NC}]  Configurar mapeamento"
        box_row "  [3]  Resetar" "  [${VERMELHO}3${NC}]  Resetar"
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        debug_flush
        echo ""
        read -p " > " c
        case "$c" in
            1)
                if [[ "$native" == "yes" ]]; then
                    set_controller_native "$a" "no" || true
                    $DEBUG && log_debug "OK    suporte nativo desmarcado (appid $a)" || true
                    echo -e "  ${CHECK} suporte nativo desmarcado"
                else
                    set_controller_native "$a" "yes" || true
                    $DEBUG && log_debug "OK    suporte nativo marcado (appid $a)" || true
                    echo -e "  ${CHECK} suporte nativo marcado"
                fi
                loading_dots 1
                continue ;;
            2)
                $DEBUG && log_debug "OK    iniciando configuração de mapeamento (appid $a)" || true
                local novo_map=""
                if gamepad_tool_installed; then
                    novo_map=$(gamepad_tool_run_and_capture) || true
                else
                    novo_map=$(input_sdl_mapping) || true
                fi
                if [[ -n "$novo_map" ]]; then
                    set_controller_mapping "$a" "$novo_map" || true
                    echo -e "  ${CHECK} mapeamento salvo"
                    sleep 0.5
                    continue
                fi
                sleep 1 ; true ;;
            3)
                reset_controller_override "$a" || true
                echo -e "  ${CHECK} configurações resetadas"
                sleep 1 ; true ;;
            0) return ;;
            *) invalid_option ;;
        esac
    done
}

# ===============
# MENU DE CONTROLES (GLOBAL)
# ===============

show_controller_device_menu() {
    local dname="$1"
    while true; do
        local global_map=""
        [[ -f "$CONTROLLER_GLOBAL_CONF" ]] && global_map=$(cat "$CONTROLLER_GLOBAL_CONF" || true)

        local tool_installed=false
        gamepad_tool_installed && tool_installed=true

        local opt_configure=1 opt_update=0 opt_reset opt_remove=0 next=2
        if $tool_installed && [[ -n "$GAMEPAD_TOOL_UPDATE_AVAILABLE" ]]; then
            opt_update=$next; ((next++))
        fi
        opt_reset=$next; ((next++))
        if $tool_installed; then
            opt_remove=$next; ((next++))
        fi

        clear
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-tui ${AGL}${NC}"
        box_top
        box_mid "$dname"
        if [[ -n "$global_map" ]] && is_valid_mapping "$global_map"; then
            box_row "  Status: mapeamento ativo"
        else
            box_row "  Status: sem mapeamento"
        fi
        box_row ""
        if $tool_installed; then
            box_row "  [${opt_configure}]  Configurar mapeamento geral" "  [${AMARELO}${opt_configure}${NC}]  Configurar mapeamento geral"
        else
            box_row "  [${opt_configure}]  Baixar gamepad-tool" "  [${AMARELO}${opt_configure}${NC}]  Baixar gamepad-tool"
        fi
        if (( opt_update > 0 )); then
            box_row "  [${opt_update}]  Atualização disponível (v${GAMEPAD_TOOL_UPDATE_AVAILABLE})" "  [${AMARELO}${opt_update}${NC}]  Atualização disponível (v${GAMEPAD_TOOL_UPDATE_AVAILABLE})"
        fi
        box_row "  [${opt_reset}]  Resetar" "  [${VERMELHO}${opt_reset}${NC}]  Resetar"
        if (( opt_remove > 0 )); then
            box_row "  [${opt_remove}]  Remover gamepad-tool" "  [${VERMELHO}${opt_remove}${NC}]  Remover gamepad-tool"
        fi
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        debug_flush
        echo ""
        read -p " > " c

        if [[ "$c" == "0" ]]; then
            return
        elif [[ "$c" == "$opt_configure" ]]; then
            if $tool_installed; then
                $DEBUG && log_debug "OK    configurando mapeamento geral" || true
                local novo_map=""
                novo_map=$(gamepad_tool_run_and_capture) || true
                if [[ -n "$novo_map" ]]; then
                    echo "$novo_map" > "$CONTROLLER_GLOBAL_CONF" || true
                    $DEBUG && log_debug "OK    mapeamento geral salvo" || true
                    echo -e "  ${CHECK} mapeamento geral salvo"
                fi
            else
                gamepad_tool_download || true
            fi
            loading_dots 1
        elif (( opt_update > 0 )) && [[ "$c" == "$opt_update" ]]; then
            gamepad_tool_download || true
            loading_dots 1
        elif [[ "$c" == "$opt_reset" ]]; then
            rm -f "$CONTROLLER_GLOBAL_CONF" || true
            $DEBUG && log_debug "OK    mapeamento geral resetado" || true
            echo -e "  ${CHECK} mapeamento geral resetado"
            loading_dots 1
        elif (( opt_remove > 0 )) && [[ "$c" == "$opt_remove" ]]; then
            echo ""
            echo -e "  Remover gamepad-tool? (s/N)"
            read -p " > " resp
            case "${resp,,}" in
                s|sim)
                    echo -e "  ${CINZA}[INFO] removendo gamepad-tool ..${NC}"
                    gamepad_tool_remove
                    echo -e "  ${CHECK} gamepad-tool removido"
                    sleep 1 ;;
            esac
        else
            invalid_option
        fi
    done
}

show_controllers_menu() {
    local devices=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && devices+=("$line")
    done < <(detect_controllers)

    gamepad_tool_check_update

    while true; do
        clear
        echo ""
        local debug_tag=""
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-tui ${AGL}${NC}"
        box_top
        box_mid "Controles"
        if [[ ${#devices[@]} -eq 0 ]]; then
            box_row "  nenhum controle detectado"
        else
            local idx=1
            for dname in "${devices[@]}"; do
                box_row "  [${idx}]  ${dname}" "  [${AMARELO}${idx}${NC}]  ${dname}"
                ((idx++))
            done
        fi
        box_mid "Sair"
        box_row "  [0]  Voltar"
        box_bottom
        debug_flush
        echo ""
        read -p " > " c

        case "$c" in
            0) return ;;
            [1-9]|[1-9][0-9])
                if (( ${#devices[@]} > 0 && c >= 1 && c <= ${#devices[@]} )); then
                    show_controller_device_menu "${devices[$((c-1))]}"
                else
                    invalid_option
                fi ; true ;;
            *) invalid_option ;;
        esac
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
        $DEBUG && debug_tag="[DEBUG] " || true
        echo -e "  ${CINZA}${debug_tag}v${VERSION} // steam-tui ${AGL}${NC}"

        if [[ ${#GAMES[@]} -eq 0 ]]; then
            box_top
            box_mid "Loja"
            box_row "  [B]  Baixar jogos" "  [${VERDE}B${NC}]  Baixar jogos"
            box_mid "Sair"
            box_row "  [0]  Fechar" "  [${VERMELHO}0${NC}]  Fechar"
            box_bottom
            debug_flush
            read -p " > " c
            case "$c" in
                0) $DEBUG && log_debug "OK    fechando steam-tui"; prompt_exit_steam; exit 0 ; true ;;
                [bB]) $DEBUG && log_debug "OK    acessando baixar jogos"; baixar_jogos; scan_games; filter_games ; true ;;
                *) invalid_option ;;
            esac
        else
            box_top
            box_mid "Loja"
            box_row "  [B]  Baixar jogos" "  [${VERDE}B${NC}]  Baixar jogos"
            box_mid "Biblioteca"
            local idx=1 a n i l p native mapping icon plat display_n padded
            for game in "${GAMES[@]}"; do
                IFS='|' read -r a n i l p _ <<< "$game"
                IFS='|' read -r native mapping <<< "$(controller_status "$a")"
                if [[ "$native" == "yes" ]] || { [[ -n "$mapping" ]] && is_valid_mapping "$mapping"; }; then
                    icon="$ICON_GAMEPAD"
                else
                    icon="$ICON_KEYBOARD"
                fi
                plat=$([ "$p" = "linux" ] && echo "$ICON_LINUX" || echo "$ICON_WINDOWS")
                display_n=$(truncate_name "$n" 22)
                padded=$(pad_to_width "  [${idx}]  ${display_n}" 34)
                box_row "${padded}${icon}  ${plat}"
                ((idx++))
            done
            box_mid "Config"
            box_row "  [C]  Controle" "  [${AMARELO}C${NC}]  Controle"
            box_row "  [D]  Dependências" "  [${AMARELO}D${NC}]  Dependências"
            box_mid "Sair"
            box_row "  [0]  Fechar" "  [${VERMELHO}0${NC}]  Fechar"
            box_bottom
            debug_flush
            echo ""
            read -p " > " c
            case "$c" in
                0) $DEBUG && log_debug "OK    fechando steam-tui"; prompt_exit_steam; exit 0 ; true ;;
                [bB]) $DEBUG && log_debug "OK    acessando baixar jogos"; baixar_jogos; scan_games; filter_games ; true ;;
                [cC]) $DEBUG && log_debug "OK    acessando controles"; show_controllers_menu ; true ;;
                [dD]) $DEBUG && log_debug "OK    acessando dependências"; show_deps_menu ; true ;;
                [1-9]|[1-9][0-9])
                    if (( c >= 1 && c <= ${#GAMES[@]} )); then
                        show_game_menu "${GAMES[$((c-1))]}"
                        loading_dots 1
                        scan_games
                        filter_games
                    else
                        invalid_option
                    fi ; true ;;
                *) invalid_option ;;
            esac
        fi
    done
}

