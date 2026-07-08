#
# © 2026 steam-cli ~ AGL ~ github.com/aglairdev
#
# ===============
# LARGURA DE EXIBIÇÃO
# ===============

display_width() {
    local s="$1" w=0 i o
    for (( i=0; i<${#s}; i++ )); do
        o=$(printf '%d' "'${s:$i:1}" 2>/dev/null || echo 0)
        if (( o >= 0xF0000 )); then
            ((w+=2))
        else
            ((w++))
        fi
    done
    echo "$w"
}

truncate_name() {
    local name="$1" max="${2:-24}"
    local w
    w=$(display_width "$name")
    if (( w <= max )); then
        echo "$name"
    else
        local truncated="" cw=0 i
        for (( i=0; i<${#name}; i++ )); do
            local c="${name:$i:1}"
            local co
            co=$(printf '%d' "'$c" 2>/dev/null || echo 0)
            local cw_add=1
            (( co >= 0xF0000 )) && cw_add=2
            if (( cw + cw_add + 3 > max )); then
                break
            fi
            truncated+="$c"
            (( cw += cw_add ))
        done
        echo "${truncated}..."
    fi
}

pad_to_width() {
    local s="$1" target="$2"
    local w
    w=$(display_width "$s")
    local diff=$((target - w))
    (( diff < 0 )) && diff=0
    printf '%s%*s' "$s" "$diff" ""
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
    local h=$((mins / 60))
    local m=$((mins % 60))
    if (( h > 0 )); then
        echo "${h}h${m}m"
    else
        echo "${m}m"
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
# BOX
# ===============

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
    local titulo="$1" len
    len=$(display_width "$titulo")
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
    local pw
    pw=$(display_width "$plano")
    local pad=$((BOXW - pw))
    (( pad < 0 )) && pad=0
    local esp
    esp=$(printf '%*s' "$pad" "")
    echo -e "${AZUL}│${NC}${colorido}${esp}${AZUL}│${NC}"
}

