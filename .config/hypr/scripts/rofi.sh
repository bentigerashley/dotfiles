#!/bin/bash

# Rofi is a layer surface, so Hyprland's normal window opacity rules do not
# apply to it.  Read the same source of truth as the app rules and pass that
# value into Rofi's theme for every launcher that uses this wrapper.
set -euo pipefail

rules_file="$HOME/.config/hypr/rules.lua"
window_opacity=$(sed -nE 's/^local window_opacity = ([0-9]+(\.[0-9]+)?).*/\1/p' "$rules_file" | head -n 1)

if [[ ! "$window_opacity" =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]]; then
    window_opacity=1.0
fi

opacity_percent=$(awk -v opacity="$window_opacity" 'BEGIN { printf "%d", (opacity * 100) + 0.5 }')

exec rofi -theme-str "* {
    bg: rgba(16, 19, 27, ${opacity_percent}%);
    bg-alt: rgba(24, 29, 40, ${opacity_percent}%);
    bg-hover: rgba(36, 40, 50, ${opacity_percent}%);
}" "$@"
