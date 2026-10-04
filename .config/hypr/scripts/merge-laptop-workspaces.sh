#!/usr/bin/env bash
# Fold hidden laptop-only workspaces into the currently focused physical page
# after docking.  Hyprland keeps those workspaces alive after their keybinds
# are removed, so without this hand-off their windows are still running but
# unreachable.
set -Eeuo pipefail

readonly laptop_monitor="${LAPTOP_MONITOR:-eDP-1}"
readonly laptop_workspace_pattern='^[1-4]$'
readonly runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"

has_independent_external_monitor() {
    local monitors_json="$1"

    jq -e --arg laptop_monitor "$laptop_monitor" '
        any(.[];
            .name != $laptop_monitor
            and ((.mirrorOf // "none") == "none")
        )
    ' >/dev/null <<<"$monitors_json"
}

hidden_laptop_workspace_windows() {
    local monitors_json="$1"
    local clients_json="$2"
    local visible_workspaces

    visible_workspaces="$(jq -c '[.[].activeWorkspace.name]' <<<"$monitors_json")"

    jq -r \
        --argjson visible_workspaces "$visible_workspaces" \
        --arg workspace_pattern "$laptop_workspace_pattern" '
            .[]
            | (.workspace.name // "") as $workspace
            | select($workspace | test($workspace_pattern))
            | select($visible_workspaces | index($workspace) | not)
            | .address
        ' <<<"$clients_json"
}

non_laptop_workspace_windows() {
    local clients_json="$1"

    # Special and named workspaces are intentionally left alone.  Only normal
    # numbered workspaces outside the laptop's 1--4 range are folded away.
    jq -r \
        --arg workspace_pattern "$laptop_workspace_pattern" '
            .[]
            | (.workspace.name // "") as $workspace
            | select($workspace | test("^[0-9]+$"))
            | select($workspace | test($workspace_pattern) | not)
            | .address
        ' <<<"$clients_json"
}

move_windows_to_workspace() {
    local target_workspace="$1"
    shift
    local address lua_workspace

    (($# > 0)) || return 0

    # The target is constant for the batch.  Escape it once; escape each
    # window address separately inside the loop.
    lua_workspace="$(jq -Rn --arg value "$target_workspace" '$value')"

    for address in "$@"; do
        # Hyprland 0.56's `hyprctl dispatch` evaluates Lua rather than
        # accepting legacy dispatcher strings.  Build Lua string literals
        # through jq so workspace names and selectors stay safely quoted.
        local lua_window
        lua_window="$(jq -Rn --arg value "address:${address}" '$value')"
        hyprctl repl "return hl.dispatch(hl.dsp.window.move({ workspace = ${lua_workspace}, window = ${lua_window}, follow = false }))" >/dev/null
    done
}

run_self_test() {
    local laptop_only='[
        {"name":"eDP-1","focused":true,"mirrorOf":"none","activeWorkspace":{"name":"1"}}
    ]'
    local real_external='[
        {"name":"eDP-1","focused":false,"mirrorOf":"none","activeWorkspace":{"name":"3"}},
        {"name":"HDMI-A-2","focused":true,"mirrorOf":"none","activeWorkspace":{"name":"5"}},
        {"name":"DP-1","focused":false,"mirrorOf":"none","activeWorkspace":{"name":"2"}}
    ]'
    local mirrored_external='[
        {"name":"eDP-1","focused":true,"mirrorOf":"none","activeWorkspace":{"name":"1"}},
        {"name":"HDMI-A-2","focused":false,"mirrorOf":"eDP-1","activeWorkspace":{"name":"1"}}
    ]'
    local clients='[
        {"address":"0xhidden-one","workspace":{"name":"1"}},
        {"address":"0xvisible-two","workspace":{"name":"2"}},
        {"address":"0xhidden-four","workspace":{"name":"4"}},
        {"address":"0xother","workspace":{"name":"special"}}
    ]'

    ! has_independent_external_monitor "$laptop_only"
    has_independent_external_monitor "$real_external"
    ! has_independent_external_monitor "$mirrored_external"

    [[ "$(hidden_laptop_workspace_windows "$real_external" "$clients")" == $'0xhidden-one\n0xhidden-four' ]]

    # With workspace 2 active on a physical monitor, it must not be folded.
    local real_external_with_workspace_two
    real_external_with_workspace_two='[
        {"name":"eDP-1","focused":false,"mirrorOf":"none","activeWorkspace":{"name":"1"}},
        {"name":"HDMI-A-2","focused":true,"mirrorOf":"none","activeWorkspace":{"name":"2"}}
    ]'
    [[ "$(hidden_laptop_workspace_windows "$real_external_with_workspace_two" "$clients")" == $'0xhidden-four' ]]

    [[ "$(non_laptop_workspace_windows '[
        {"address":"0xworkspace-five","workspace":{"name":"5"}},
        {"address":"0xlaptop-one","workspace":{"name":"1"}},
        {"address":"0xspecial","workspace":{"name":"special:magic"}}
    ]')" == "0xworkspace-five" ]]

    printf 'workspace merge self-test: passed\n'
}

if [[ "${1:-}" == "--self-test" ]]; then
    run_self_test
    exit 0
fi

# Multiple outputs may be announced during one dock event.  Only one of their
# delayed handlers should perform the merge.
exec 9>"$runtime_dir/hypr-merge-laptop-workspaces.lock"
flock -n 9 || exit 0

monitors_json="$(hyprctl -j monitors)"

if ! has_independent_external_monitor "$monitors_json"; then
    # An external monitor's active workspace survives its removal.  If that
    # was workspace 5 (or higher), it becomes an invisible laptop workspace
    # and can keep Firefox and other windows unreachable.  First activate 1,
    # then move every non-laptop numbered workspace into it.  Once empty, the
    # former workspace is automatically removed by Hyprland.
    hyprctl repl 'return hl.dispatch(hl.dsp.focus({ workspace = 1 }))' >/dev/null

    clients_json="$(hyprctl -j clients)"
    mapfile -t non_laptop_windows < <(non_laptop_workspace_windows "$clients_json")
    move_windows_to_workspace "1" "${non_laptop_windows[@]}"
    exit 0
fi

target_workspace="$(jq -er '[.[] | select(.focused == true) | .activeWorkspace.name] | first // empty' <<<"$monitors_json")"
[[ -n "$target_workspace" ]] || exit 0

clients_json="$(hyprctl -j clients)"
mapfile -t hidden_windows < <(hidden_laptop_workspace_windows "$monitors_json" "$clients_json")
move_windows_to_workspace "$target_workspace" "${hidden_windows[@]}"
