#!/usr/bin/env bash

# Quickshell identifies instances by configuration, so only ever stop the
# wallpaper picker—not any other Quickshell shell the user might be running.
if pgrep -f '[q]uickshell.*(-c|--config)[[:space:]]+hyprquickpaper' >/dev/null; then
    pkill -f '[q]uickshell.*(-c|--config)[[:space:]]+hyprquickpaper'
else
    exec quickshell --no-duplicate --config hyprquickpaper
fi
