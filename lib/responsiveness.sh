#
# © 2026 steam-tui ~ AGL ~ github.com/aglairdev
#
# ===============
# RESPONSIVIDADE
# ===============

MIN_COLS=73
MIN_LINES=31

RESIZE_IN_PROGRESS=0
RESIZE_POLL_INTERVAL="0.2"

RESIZED=0

on_resize() {
    RESIZE_IN_PROGRESS=1
    RESIZED=1
}
trap on_resize SIGWINCH

get_term_width() {
    stty size 2>/dev/null | cut -d' ' -f2 || tput cols 2>/dev/null || echo 80
}

get_term_height() {
    stty size 2>/dev/null | cut -d' ' -f1 || tput lines 2>/dev/null || echo 24
}

term_too_small() {
    local width height
    width=$(get_term_width)
    height=$(get_term_height)
    (( width < MIN_COLS || height < MIN_LINES ))
}

_too_small_line() {
    local row="$1" width="$2" msg="$3" color="$4"
    local msg_len=${#msg} col
    if (( msg_len > width )); then
        msg="${msg:0:width}"
        msg_len=$width
    fi
    col=$(( (width - msg_len) / 2 + 1 ))
    (( col < 1 )) && col=1
    printf '\033[%d;%dH' "$row" "$col"
    echo -e "${color}${msg}${NC}"
}

draw_too_small() {
    local width height msg1 msg2 row1 row2
    width=$(get_term_width)
    height=$(get_term_height)

    if (( width < MIN_COLS )); then
        msg1="Amplie a largura do terminal."
    else
        msg1="Amplie a altura do terminal."
    fi
    msg2="Mínimo: ${MIN_COLS}x${MIN_LINES}  |  Atual: ${width}x${height}"

    clear

    row1=$(( (height - 2) / 2 + 1 ))
    row2=$(( row1 + 1 ))

    (( row1 < 1 )) && row1=1
    (( row2 > height )) && row2=$height

    _too_small_line "$row1" "$width" "$msg1" "$VERMELHO"
    _too_small_line "$row2" "$width" "$msg2" "$CINZA"
}

wait_for_resize() {
    while term_too_small; do
        draw_too_small
        sleep 0.3
    done
}
