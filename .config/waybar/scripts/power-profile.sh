#!/bin/sh

# Report and cycle the profiles exposed by power-profiles-daemon.  The driver
# decides what is available, so this works on machines without every mode.
set -eu

action=${1:-status}

profiles=$(powerprofilesctl list 2>/dev/null) || {
    printf '%s\n' '{"text":"PWR: N/A","class":"unavailable","tooltip":"Power profiles are unavailable"}'
    exit 0
}

has_profile() {
    printf '%s\n' "$profiles" | grep -Eq "^[*[:space:]]{0,3}$1:"
}

current=$(powerprofilesctl get 2>/dev/null || true)

if [ "$action" = "cycle" ]; then
    # Battery saver → balanced → performance → battery saver.  Skip any mode
    # unavailable on this hardware instead of attempting an invalid change.
    case "$current" in
        power-saver) candidates='balanced performance power-saver' ;;
        balanced)    candidates='performance power-saver balanced' ;;
        performance) candidates='power-saver balanced performance' ;;
        *)           candidates='power-saver balanced performance' ;;
    esac

    for candidate in $candidates; do
        if has_profile "$candidate"; then
            powerprofilesctl set "$candidate" 2>/dev/null || true
            break
        fi
    done
    exit 0
fi

case "$current" in
    power-saver)
        text='PWR: SAVER'
        class='power-saver'
        tooltip='Battery Saver — click to switch to Balanced'
        ;;
    balanced)
        text='PWR: BALANCED'
        class='balanced'
        tooltip='Balanced — click to switch to Performance'
        ;;
    performance)
        text='PWR: PERFORMANCE'
        class='performance'
        tooltip='Performance — click to switch to Battery Saver'
        ;;
    *)
        text='PWR: N/A'
        class='unavailable'
        tooltip='Power profile could not be determined'
        ;;
esac

printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$text" "$class" "$tooltip"
