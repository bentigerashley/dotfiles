#!/bin/sh

# Keep the logout HUD centred on the focused output.  Wlogout's margins are
# logical pixels, so fixed desktop-sized values put the menu off-screen on the
# 1.5-scale laptop panel.
set -eu

set -- $(hyprctl -j monitors | jq -r '
    .[] | select(.focused)
    | [(.width / .scale | floor), (.height / .scale | floor)]
    | @tsv
' | head -n 1)

logical_width=${1:-1280}
logical_height=${2:-720}

# The original desktop HUD was a 440 × 430 logical-pixel panel.  Keep that
# size when it fits, otherwise reduce it proportionally for smaller outputs.
panel_width=$((logical_width * 34 / 100))
panel_height=$((logical_height * 60 / 100))

[ "$panel_width" -lt 300 ] && panel_width=300
[ "$panel_width" -gt 440 ] && panel_width=440
[ "$panel_height" -lt 360 ] && panel_height=360
[ "$panel_height" -gt 430 ] && panel_height=430

margin_left=$(( (logical_width - panel_width) / 2 ))
margin_top=$(( (logical_height - panel_height) / 2 ))

exec wlogout -b 1 -c 20 -r 20 \
    -L "$margin_left" -R "$margin_left" \
    -T "$margin_top" -B "$margin_top"
