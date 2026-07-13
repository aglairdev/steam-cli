#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
# ===============
# LOGO
# ===============

LOGO_WORD=("S" "T" "E" "A" "M" "-" "T" "U" "I")

_glyph_row() {
    local ch="$1" row="$2"
    case "$ch" in
        S) case "$row" in
               0) echo "▄██" ;; 1) echo "█▄▄" ;; 2) echo "▄▄█" ;;
           esac ;;
        T) case "$row" in
               0) echo "███" ;; 1) echo " █ " ;; 2) echo " █ " ;;
           esac ;;
        E) case "$row" in
               0) echo "███" ;; 1) echo "█▀ " ;; 2) echo "███" ;;
           esac ;;
        A) case "$row" in
               0) echo " █ " ;; 1) echo "███" ;; 2) echo "█ █" ;;
           esac ;;
        M) case "$row" in
               0) echo "█▄█" ;; 1) echo "███" ;; 2) echo "█ █" ;;
           esac ;;
        -) case "$row" in
               0) echo "   " ;; 1) echo "███" ;; 2) echo "   " ;;
           esac ;;
        U) case "$row" in
               0) echo "█ █" ;; 1) echo "█ █" ;; 2) echo "███" ;;
           esac ;;
        I) case "$row" in
               0) echo "███" ;; 1) echo " █ " ;; 2) echo "███" ;;
           esac ;;
        *) echo "   " ;;
    esac
}

LOGO_HEIGHT=5

render_logo() {
    local width rows=3
    width=$(get_term_width)

    local r1=225 g1=238 b1=255
    local r2=70  g2=135 b2=230

    local row ch glyph_lines=() line
    for (( row=0; row<rows; row++ )); do
        line=""
        for ch in "${LOGO_WORD[@]}"; do
            line+="$(_glyph_row "$ch" "$row") "
        done
        glyph_lines+=("$line")
    done

    local line_width=${#glyph_lines[0]}
    local total_pad=$(( (width - line_width) / 2 ))
    (( total_pad < 0 )) && total_pad=0
    local margin
    margin=$(printf '%*s' "$total_pad" "")

    local rr gg bb color
    for (( row=0; row<rows; row++ )); do
        line="${glyph_lines[$row]}"
        rr=$(( r1 + (r2 - r1) * row / (rows - 1) ))
        gg=$(( g1 + (g2 - g1) * row / (rows - 1) ))
        bb=$(( b1 + (b2 - b1) * row / (rows - 1) ))
        color=$(printf '\033[38;2;%d;%d;%dm' "$rr" "$gg" "$bb")
        echo -e "${margin}${color}${NEGRITO}${line}${NC}"
        FRAME_LINES=$((FRAME_LINES+1))
    done

    render_rule

    echo ""
    FRAME_LINES=$((FRAME_LINES+1))
}