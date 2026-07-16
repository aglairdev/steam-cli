#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
# ===============
# LARGURA
# ===============

strip_ansi() {
    printf '%s' "$1" | sed -E 's/\x1b\[[0-9;]*m//g; s/\\033\[[0-9;]*m//g; s/\\e\[[0-9;]*m//g'
}

display_width() {
    local str="$1"
    (( ${#str} > 500 )) && str="${str:0:500}"
    echo "${#str}"
}

truncate_name() {
    local name="$1" max="${2:-24}"
    (( ${#name} > 500 )) && name="${name:0:500}"
    if (( ${#name} <= max )); then
        echo "$name"
    else
        local trunc_len=$(( max - 3 ))
        (( trunc_len < 0 )) && trunc_len=0
        echo "${name:0:trunc_len}..."
    fi
}

pad_to_width() {
    local str="$1" target="$2"
    local width
    width=$(display_width "$str")
    local diff=$((target - width))
    (( diff < 0 )) && diff=0
    printf '%s%*s' "$str" "$diff" ""
}

print_centered() {
    local str="$1" term_width plain width pad
    term_width=$(get_term_width)
    plain=$(strip_ansi "$str")
    width=$(display_width "$plain")
    pad=$(( (term_width - width) / 2 ))
    (( pad < 0 )) && pad=0
    printf '%*s' "$pad" ""
    echo -e "$str"
    FRAME_LINES=$((FRAME_LINES+1))
}

# ===============
# TEMPO DE JOGO
# ===============

format_playtime() {
    local mins="$1"
    if [[ -z "$mins" || "$mins" -eq 0 ]]; then
        echo "0h"
        return
    fi
    local hours=$((mins / 60))
    local minutes=$((mins % 60))
    if (( hours > 0 )); then
        echo "${hours}h${minutes}m"
    else
        echo "${minutes}m"
    fi
}

get_playtime() {
    local appid="$1"
    local vdf
    vdf=$(find "$HOME/.steam/steam/userdata/" -name "localconfig.vdf" 2>/dev/null | head -1)
    [[ -f "$vdf" ]] || { echo "0"; return; }
    awk -v id="$appid" '
        /^[[:space:]]*"[0-9]+"[[:space:]]*$/ { current_app = $0; gsub(/[^0-9]/, "", current_app) }
        current_app == id && /[[:space:]]*"Playtime"[[:space:]]*"[0-9]+"/ {
            gsub(/.*"Playtime"[[:space:]]*"/, ""); gsub(/".*/, ""); print; exit
        }
    ' "$vdf" || echo "0"
}

# ===============
# TERMINAL / BOX
# ===============

BOX_MIN=50
BOX_MAX=90

BOXW=44
LPAD=""

box_init() {
    local term_width
    term_width=$(get_term_width)
    local desired=$(( term_width * 70 / 100 ))

    (( desired < BOX_MIN )) && desired=$BOX_MIN
    (( desired > BOX_MAX )) && desired=$BOX_MAX
    (( desired > term_width - 4 )) && desired=$(( term_width - 4 ))
    (( desired < 20 )) && desired=20

    BOXW=$desired

    local margin=$(( (term_width - BOXW) / 2 ))
    (( margin < 0 )) && margin=0

    LPAD=$(printf '%*s' "$margin" "")
}

# ===============
# RÉGUA
# ===============

theme_rule() {
    local len="$1"
    printf '─%.0s' $(seq 1 "$len")
}

render_rule() {
    local term_width rule_len rpad rule
    term_width=$(get_term_width)
    rule_len=$(( term_width * 22 / 100 ))
    (( rule_len > 22 )) && rule_len=22
    (( rule_len < 8 )) && rule_len=8
    rule=$(theme_rule "$rule_len")
    rpad=$(( (term_width - rule_len) / 2 ))
    (( rpad < 0 )) && rpad=0
    printf '%*s' "$rpad" ""
    echo -e "${AZUL}${rule}${NC}"
    FRAME_LINES=$((FRAME_LINES+1))
}

# ===============
# BOX
# ===============

FRAME_LINES=0

box_top() {
    local border
    border=$(printf '─%.0s' $(seq 1 $BOXW))
    echo -e "${LPAD}${AZUL}┌${border}┐${NC}"
    FRAME_LINES=$((FRAME_LINES+1))
}
box_bottom() {
    local border
    border=$(printf '─%.0s' $(seq 1 $BOXW))
    echo -e "${LPAD}${AZUL}└${border}┘${NC}"
    FRAME_LINES=$((FRAME_LINES+1))
}
box_mid() {
    local title="$1" title_len
    title_len=$(display_width "$title")

    if (( title_len > BOXW - 4 )); then
        title=$(truncate_name "$title" $((BOXW - 4)))
        title_len=$(display_width "$title")
    fi

    local total=$((BOXW - title_len - 2))
    local left_dashes right_dashes left_rule right_rule
    left_dashes=$((total / 2))
    right_dashes=$((total - left_dashes))
    left_rule=$(printf '─%.0s' $(seq 1 $left_dashes))
    right_rule=$(printf '─%.0s' $(seq 1 $right_dashes))
    echo -e "${LPAD}${AZUL}├${left_rule} ${title} ${right_rule}┤${NC}"
    FRAME_LINES=$((FRAME_LINES+1))
}
box_row() {
    local plain="$1" colored="${2:-$1}"
    local plain_width
    plain_width=$(display_width "$(strip_ansi "$plain")")
    local pad=$((BOXW - plain_width))
    (( pad < 0 )) && pad=0
    local padding
    padding=$(printf '%*s' "$pad" "")
    echo -e "${LPAD}${AZUL}│${NC}${colored}${padding}${AZUL}│${NC}"
    FRAME_LINES=$((FRAME_LINES+1))
}
box_row_blank() {
    box_row ""
}

SEL_BG='\033[48;2;35;65;100m'
SEL_MARK='\033[38;2;140;190;255m'
SEL_BG_DANGER='\033[48;2;100;40;40m'
SEL_MARK_DANGER='\033[38;2;255;180;180m'
SEL_BG_SUCCESS='\033[48;2;40;80;40m'
SEL_MARK_SUCCESS='\033[38;2;150;220;150m'

box_row_selected() {
    local plain="$1" variant="${2:-normal}"
    [[ "$variant" == true ]] && variant="danger"
    [[ "$variant" == false ]] && variant="normal"
    local marked="> ${plain:2}"
    local marked_width
    marked_width=$(display_width "$(strip_ansi "$marked")")
    local pad=$((BOXW - marked_width))
    (( pad < 0 )) && pad=0
    local padding
    padding=$(printf '%*s' "$pad" "")
    local bg mark
    case "$variant" in
        danger)  bg="$SEL_BG_DANGER";  mark="$SEL_MARK_DANGER" ;;
        success) bg="$SEL_BG_SUCCESS"; mark="$SEL_MARK_SUCCESS" ;;
        *)       bg="$SEL_BG";         mark="$SEL_MARK" ;;
    esac
    echo -e "${LPAD}${AZUL}│${NC}${bg}${mark}>${NC}${bg} ${plain:2}${padding}${NC}${AZUL}│${NC}"
    FRAME_LINES=$((FRAME_LINES+1))
}

DANGER_ITEMS_REGEX='^(Excluir|Resetar|Limpar|Remover.*)$'
SUCCESS_ITEMS_REGEX='^(instalar todas)$'

box_items() {
    local sel="$1"; shift
    local idx=0 item
    for item in "$@"; do
        local variant="normal" label="$item"
        if [[ "$item" =~ $DANGER_ITEMS_REGEX ]]; then
            variant="danger"; label="[${item}]"
        elif [[ "$item" =~ $SUCCESS_ITEMS_REGEX ]]; then
            variant="success"; label="[${item}]"
        fi
        if (( idx == sel )); then
            box_row_selected "  ${label}" "$variant"
        elif [[ "$variant" == "danger" ]]; then
            box_row "  ${label}" "  ${VERMELHO_CLARO}${label}${NC}"
        elif [[ "$variant" == "success" ]]; then
            box_row "  ${label}" "  ${VERDE}${NEGRITO}${label}${NC}"
        else
            box_row "  ${item}"
        fi
        idx=$((idx+1))
    done
}

# ===============
# TELA ESTÁTICA
# ===============

DEBUG_MODE=false

render_static_screen() {
    local content="$1"

    clear

    local term_height=$(get_term_height)
    local content_lines=$(printf "%s" "$content" | wc -l)

    local offset=2
    local top_pad=$(( (term_height - content_lines) / 2 + offset ))

    [[ $top_pad -lt 0 ]] && top_pad=0

    local pad_line
    for (( pad_line=0; pad_line<top_pad; pad_line++ )); do echo ""; done

    printf "%b\n" "$content"

    if [ "$DEBUG_MODE" = true ]; then
        tput cup 0 0
        printf '\033[100m %dx%d ~ logs: %s \033[0m' "$(get_term_width)" "$term_height" "${DEBUG_LOG:-$CONFIG_DIR/debug.log}"
    fi

    printf '\e[?25l' 2>/dev/null
}

# ===============
# INPUT NO BOX
# ===============

box_row_input() {
    local value="$1" mask="${2:-false}"
    local prefix="  > "
    local prefix_width
    prefix_width=$(display_width "$prefix")
    local avail=$(( BOXW - prefix_width - 1 ))
    (( avail < 1 )) && avail=1
    local shown="$value"
    if [[ "$mask" == true ]]; then
        shown=$(printf '%*s' "${#value}" "" | tr ' ' '*')
    fi
    local shown_width
    shown_width=$(display_width "$shown")
    if (( shown_width > avail )); then
        shown="${shown: -avail}"
    fi
    box_row "${prefix}${shown}█"
}

box_row_hint() {
    local plain="  [Enter] Confirmar   [Esq] Cancelar"
    local colored="  ${AZUL}[Enter]${NC} Confirmar   ${AZUL}[Esq]${NC} Cancelar"
    box_row "$plain" "$colored"
}

_read_input_key() {
    local key rest
    if ! IFS= read -rsn1 -t "$RESIZE_POLL_INTERVAL" key; then
        if (( RESIZED )); then
            echo "RESIZE"
        else
            echo "IDLE"
        fi
        return
    fi
    if [[ $key == $'\x1b' ]]; then
        IFS= read -rsn2 -t 0.05 rest 2>/dev/null || true
        key+="$rest"
        if [[ "$key" == $'\x1b' || "$key" == $'\x1b[D' ]]; then
            echo "LEFT"
        else
            echo "IGNORE"
        fi
        return
    fi
    case "$key" in
        ""|$'\x0a'|$'\x0d') echo "ENTER" ;;
        $'\x7f'|$'\x08') echo "BACKSPACE" ;;
        *) echo "CHAR:$key" ;;
    esac
}

INPUT_RESULT=""

_is_safe_char() {
    local c="$1" code
    code=$(printf '%d' "'$c" 2>/dev/null || echo -1)
    (( code >= 32 && code != 127 ))
}

box_read_input() {
    local draw_fn="$1"
    local value=""
    INPUT_RESULT=""
    local need_redraw=true
    while true; do
        wait_for_resize
        box_init

        if $need_redraw; then
            RESIZED=0
            FRAME_LINES=0
            local content
            content=$("$draw_fn" "$value")
            render_static_screen "$content"
            need_redraw=false
        fi

        local action
        action=$(_read_input_key)
        case "$action" in
            ENTER) break ;;
            LEFT) value=""; break ;;
            BACKSPACE) value="${value%?}"; need_redraw=true ;;
            CHAR:*)
                local new_char="${action#CHAR:}"
                if _is_safe_char "$new_char"; then
                    value+="$new_char"
                    (( ${#value} > 200 )) && value="${value:0:200}"
                fi
                local drained=0
                while (( drained < 50 )) && IFS= read -rsn1 -t 0.001 next_char; do
                    if [[ "$next_char" == $'\x1b' ]]; then
                        IFS= read -rsn2 -t 0.02 _ 2>/dev/null || true
                    elif _is_safe_char "$next_char"; then
                        value+="$next_char"
                        (( ${#value} > 200 )) && value="${value:0:200}"
                    fi
                    drained=$((drained+1))
                done
                need_redraw=true
                ;;
            RESIZE) need_redraw=true ;;
            IGNORE|IDLE) : ;;
        esac
    done
    tput civis 2>/dev/null || true
    INPUT_RESULT="$value"
}

# ===============
# BUSCA (BIBLIOTECA)
# ===============

box_row_search() {
    local query="$1" active="$2" display color="$CINZA"
    if [[ "$active" == true ]]; then
        color="$AZUL"
        display="${query}█"
    elif [[ -n "$query" ]]; then
        display="$query"
    else
        display=$(printf '_%.0s' $(seq 1 12))
    fi
    print_centered "${color}[/] ${NC}${display}"
}

_read_library_search_key() {
    local key rest
    if ! IFS= read -rsn1 -t "$RESIZE_POLL_INTERVAL" key; then
        if (( RESIZED )); then
            echo "RESIZE"
        else
            echo "IDLE"
        fi
        return
    fi
    if [[ $key == $'\x1b' ]]; then
        IFS= read -rsn2 -t 0.05 rest 2>/dev/null || true
        key+="$rest"
        case "$key" in
            $'\x1b[A') echo "UP" ;;
            $'\x1b[B') echo "DOWN" ;;
            $'\x1b'|$'\x1b[D') echo "LEFT" ;;
            *) echo "IGNORE" ;;
        esac
        return
    fi
    case "$key" in
        ""|$'\x0a'|$'\x0d') echo "ENTER" ;;
        $'\x7f'|$'\x08') echo "BACKSPACE" ;;
        *) echo "CHAR:$key" ;;
    esac
}

# ===============
# CONFIRMAÇÃO
# ===============

confirm_dialog() {
    local title="$1" question="$2" question_colored="${3:-$2}"
    _draw_confirm_dialog() {
        local sel="$1" allow_back="$2"
        render_logo
        box_top
        box_mid "$title"
        local question_display question_display_colored
        if (( $(display_width "$question") > BOXW - 4 )); then
            question_display=$(truncate_name "$question" $((BOXW - 4)))
            question_display_colored="$question_display"
        else
            question_display="$question"
            question_display_colored="$question_colored"
        fi
        box_row "  ${question_display}" "  ${NEGRITO}${question_display_colored}${NC}"
        box_row_blank
        box_items "$sel" "Não" "Sim"
        box_bottom
        render_footer "$allow_back"
    }
    run_menu 2 _draw_confirm_dialog true
    [[ "$MENU_RESULT" == "1" ]]
}

# ===============
# CARREGAMENTO
# ===============

loading_dots() {
    local seconds="$1" msg="${2:-Carregando}"
    local frames=("." ".." "...") i=0 steps
    steps=$(( seconds * 3 ))
    _draw_loading_dots() {
        box_init
        render_logo
        box_top
        box_mid "${AGL} steam-tui"
        box_row "  ${msg}${frames[$((i % 3))]}" "  ${CINZA}${msg}${frames[$((i % 3))]}${NC}"
        box_bottom
    }
    while (( i < steps )); do
        render_static_screen "$(_draw_loading_dots)"
        sleep 0.33
        i=$((i + 1))
    done
}

# ===============
# STATUS BOX
# ===============

STATUS_BOX_TITLE=""
STATUS_BOX_LINES=()

status_box_start() {
    STATUS_BOX_TITLE="$1"
    STATUS_BOX_LINES=()
}

status_box_add() {
    STATUS_BOX_LINES+=("$1")
    _draw_status_box() {
        box_init
        render_logo
        box_top
        box_mid "$STATUS_BOX_TITLE"
        local line
        for line in "${STATUS_BOX_LINES[@]}"; do
            box_row "  ${line}" "  ${line}"
        done
        box_bottom
    }
    render_static_screen "$(_draw_status_box)"
}

# ===============
# RETORNO AUTOMÁTICO COM DELAY
# ===============

auto_return_delay() {
    local seconds="${1:-1.2}"
    sleep "$seconds"
}

# ===============
# RODAPÉ
# ===============

UI_MESSAGE=""

ui_log() {
    UI_MESSAGE="$1"
}

ui_log_clear() {
    UI_MESSAGE=""
}

render_footer() {
    local allow_back="${1:-true}"
    local hint
    if [[ "$allow_back" == true ]]; then
        hint="${AZUL}[↑↓]${NC} Navegar   ${AZUL}[Enter]${NC} Selecionar   ${AZUL}[Esq]${NC} Voltar   ${AZUL}[Q]${NC} Sair"
    else
        hint="${AZUL}[↑↓]${NC} Navegar   ${AZUL}[Enter]${NC} Selecionar   ${AZUL}[Q]${NC} Sair"
    fi
    echo ""
    FRAME_LINES=$((FRAME_LINES+1))
    print_centered "$hint"
    render_rule
    if [[ -n "$UI_MESSAGE" ]]; then
        local msg_color="$NC"
        [[ "$UI_MESSAGE" == "${XIS}"* ]] && msg_color="$VERMELHO_CLARO"
        [[ "$UI_MESSAGE" == "${CHECK}"* ]] && msg_color="$VERDE"
        print_centered "${msg_color}${UI_MESSAGE}${NC}"
    fi
}

# ===============
# NAVEGAÇÃO POR TECLADO
# ===============

read_key() {
    local key rest
    if ! IFS= read -rsn1 -t "$RESIZE_POLL_INTERVAL" key; then
        if (( RESIZED )); then
            echo "RESIZE"
        else
            echo "IDLE"
        fi
        return
    fi
    if [[ $key == $'\x1b' ]]; then
        IFS= read -rsn2 -t 0.05 rest 2>/dev/null || true
        key+="$rest"
        if [[ "$key" == $'\x1b' ]]; then
            echo "LEFT"
            return
        fi
    fi
    case "$key" in
        $'\x1b[A') echo "UP" ;;
        $'\x1b[B') echo "DOWN" ;;
        $'\x1b[C') echo "RIGHT" ;;
        $'\x1b[D') echo "LEFT" ;;
        k|K) echo "UP" ;;
        j|J) echo "DOWN" ;;
        l|L) echo "RIGHT" ;;
        h|H) echo "LEFT" ;;
        ""|$'\x0a'|$'\x0d') echo "ENTER" ;;
        *) echo "CHAR:$key" ;;
    esac
}

MENU_WINDOW_START=0
MENU_VISIBLE=0
MENU_RESULT=""

run_menu() {
    local n_items="$1" draw_fn="$2" allow_back="${3:-true}" visible_spec="${4:-0}"
    local sel=0
    MENU_WINDOW_START=0
    local need_redraw=true
    while true; do
        wait_for_resize
        box_init

        if [[ "$visible_spec" =~ ^[0-9]+$ ]]; then
            MENU_VISIBLE=$visible_spec
        elif [[ -n "$visible_spec" ]]; then
            MENU_VISIBLE=$("$visible_spec")
        else
            MENU_VISIBLE=0
        fi

        if (( MENU_VISIBLE > 0 && n_items > MENU_VISIBLE )); then
            (( sel < MENU_WINDOW_START )) && MENU_WINDOW_START=$sel
            (( sel >= MENU_WINDOW_START + MENU_VISIBLE )) && MENU_WINDOW_START=$(( sel - MENU_VISIBLE + 1 ))
        else
            MENU_WINDOW_START=0
        fi

        if $need_redraw; then
            RESIZED=0
            FRAME_LINES=0
            local content
            content=$("$draw_fn" "$sel" "$allow_back")
            render_static_screen "$content"
            need_redraw=false
        fi

        local action
        action=$(read_key)
        if [[ "$action" != "IDLE" && "$action" != "RESIZE" ]]; then
            ui_log_clear
        fi
        case "$action" in
            UP)    (( n_items > 0 )) && sel=$(( (sel - 1 + n_items) % n_items )); need_redraw=true ;;
            DOWN)  (( n_items > 0 )) && sel=$(( (sel + 1) % n_items )); need_redraw=true ;;
            ENTER|RIGHT)
                MENU_RESULT="$sel"; return 0 ;;
            LEFT)
                if [[ "$allow_back" == true ]]; then
                    MENU_RESULT="BACK"; return 0
                fi ;;
            CHAR:q|CHAR:Q)
                prompt_exit_steam
                clear
                tput cnorm 2>/dev/null || true
                exit 0 ;;
            RESIZE) need_redraw=true ;;
            IDLE) : ;;
        esac
    done
}

chrome_lines_scrollable() {
    local footer_lines=$(( 1 + 1 + 1 ))
    echo $(( LOGO_HEIGHT + 1 + 1 + 2 + 1 + footer_lines ))
}
