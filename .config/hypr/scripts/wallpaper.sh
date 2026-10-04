#!/usr/bin/env bash
# Keep the wallpaper picker, compositor, and lock screen on one remembered image.

set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
state_file="$state_dir/wallpaper"
default_wallpaper="$HOME/Pictures/Wallpapers/w4.png"

remember() {
    local image
    image=$(realpath -e -- "$1")
    [[ -f "$image" ]] || {
        printf 'Wallpaper is not a regular file: %s\n' "$image" >&2
        return 1
    }

    mkdir -p "$state_dir"
    local temporary
    temporary=$(mktemp "$state_dir/wallpaper.XXXXXX")
    printf '%s\n' "$image" > "$temporary"
    mv -f -- "$temporary" "$state_file"
    printf '%s\n' "$image"
}

apply() {
    local image="$1"
    shift

    # awww-daemon takes a moment to expose its socket on a fresh login.
    # Retrying here ensures Hyprlock's screenshot sees the restored wallpaper.
    local attempt
    for attempt in {1..30}; do
        if awww img "$image" "$@"; then
            return 0
        fi
        sleep 0.1
    done

    printf 'Could not set wallpaper: %s\n' "$image" >&2
    return 1
}

case "${1:-}" in
    set)
        [[ $# -ge 2 ]] || { printf 'Usage: %s set IMAGE [awww options...]\n' "$0" >&2; exit 2; }
        image=$(remember "$2")
        shift 2
        apply "$image" "$@"
        ;;
    restore)
        image="$default_wallpaper"
        if [[ -s "$state_file" ]]; then
            candidate=$(<"$state_file")
            if [[ -f "$candidate" ]]; then
                image="$candidate"
            fi
        fi

        # Starting this in the same script makes restore reliable even if the
        # Hyprland config is reloaded or its startup order changes.
        awww-daemon >/dev/null 2>&1 &
        apply "$image" -t none
        ;;
    *)
        printf 'Usage: %s {set IMAGE [awww options...]|restore}\n' "$0" >&2
        exit 2
        ;;
esac
