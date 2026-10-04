-- ~/.config/hypr/hyprland.lua
-- Docs: https://wiki.hypr.land/Configuring/Start/

-- Three-display layout, left to right:
-- HDMI-A-2 (external), DP-1 (external), eDP-1 (laptop panel).
-- Keep the laptop panel at its native 144 Hz and 1.5 scale.
hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@60",  position = "0x0",    scale = 1 })
hl.monitor({ output = "DP-1",     mode = "1920x1080@60",  position = "1920x0", scale = 1 })
hl.monitor({ output = "eDP-1",    mode = "1920x1080@144", position = "3840x0", scale = 1.5 })

-- Workspaces are useful on the laptop, but with independent external displays
-- they add a second, invisible layer of desktops to an already-large canvas.
-- A mirrored output is still the same canvas, so it deliberately keeps the
-- laptop's four-workspace workflow and its navigation controls.
-- This is deliberately global because keybinds.lua is loaded below as a
-- separate Lua module.
workspaceFeatureEnabled = true
for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.name ~= "eDP-1" and not monitor.is_mirror then
        workspaceFeatureEnabled = false
        break
    end
end

---- MY PROGRAMS ----

home       = os.getenv("HOME")
mainMod    = "SUPER"
-- Super+T terminals use a dedicated class.  Kitty asks for fullscreen before
-- its first map on this system; declaring the desired state as part of that
-- same map lets dwindle place the window directly, without a fullscreen flash.
terminal   = "kitty --class hypr-tiled-terminal --start-as=normal"
menu       = "rofi -show drun"
fileManager = "thunar"
browser    = "firefox"

-- This is evaluated while the window maps, before it can draw fullscreen.
hl.window_rule({
    name = "super-t-terminal-tiled",
    match = { class = "^hypr-tiled-terminal$" },
    fullscreen_state = "0 0",
})

-- `require("keybinds")` is cached across config reloads, so replace its old
-- terminal binding explicitly.
hl.unbind(mainMod .. " + T")
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))

-- A local build keeps this overview plugin ABI-matched to the installed
-- Hyprland release. `hl.plugin.load` is declarative and must run on every
-- config pass (the plugin becomes available on the following pass).
local hyprexpoPlugin = home .. "/.local/share/hyprexpo/hyprexpo.so"
hl.plugin.load(hyprexpoPlugin)


---- AUTOSTART ----

-- Old exec-once lines. hl.exec_cmd() fires immediately (not a dispatcher),
-- so these are wrapped in the hyprland.start event, same timing as exec-once.
-- Start Waybar from the compositor: this session does not activate
-- graphical-session.target, so its packaged systemd user service alone would
-- never be launched after a reboot.

hl.on("hyprland.start", function()
    -- Restore the chosen wallpaper before locking.  Hyprlock uses a screenshot
    -- for its background, so starting it first would capture an empty screen.
    -- Leave the session if the restore or locker cannot start, allowing SDDM to
    -- fall back to its normal login screen rather than exposing the desktop.
    hl.exec_cmd(home .. "/.config/hypr/scripts/wallpaper.sh restore && hyprlock --immediate-render || hyprctl dispatch exit")

    hl.exec_cmd("waybar")
    hl.exec_cmd("dunst")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

end)

---- ENVIRONMENT VARIABLES ----

hl.env("XCURSOR_SIZE", "14")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- On a real dock, the workspace controls above disappear.  Move windows out
-- of any non-visible laptop workspaces first, so a window is never left alive
-- but inaccessible after the profile change.  The helper is a no-op while
-- undocked or when the external display is a mirror.
hl.exec_cmd(home .. "/.config/hypr/scripts/merge-laptop-workspaces.sh")

---- INPUT ----

hl.config({
    input = {
        -- This laptop has a physical US keyboard.  Keeping a second layout here
        -- meant it could be switched accidentally, remapping punctuation such
        -- as the /? key to -_.
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0.5,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
        },
    },
})

---- LAPTOP-ONLY WORKSPACES / OVERVIEW ----

-- Keep exactly four normal workspaces available only while undocked.  The
-- setting intentionally disappears when docked; Hyprland still keeps one
-- active workspace per physical display, which is required by the compositor,
-- but there is no extra virtual-workspace layer to navigate.
if workspaceFeatureEnabled then
    for i = 1, 4 do
        hl.workspace_rule({ workspace = tostring(i), persistent = true })
    end

    hl.config({
        gestures = {
            workspace_swipe_distance = 400,
            workspace_swipe_create_new = false,
            workspace_swipe_forever = false,
        },
    })
end

-- The overview plugin is still loaded so it is ready when unplugged, but all
-- of its entry points are omitted while external displays are present.
local hyprexpoLoaded = false
for _, plugin in ipairs(hl.get_loaded_plugins()) do
    if plugin.name == "hyprexpo" then
        hyprexpoLoaded = true
        break
    end
end

if workspaceFeatureEnabled and hyprexpoLoaded then
    hl.config({
        plugin = {
            hyprexpo = {
                -- Fixed 2×2 selector: always show workspaces 1–4, including
                -- empty ones, rather than shrinking the overview to active
                -- desktops only.
                columns = 2,
                gaps_in = 16,
                gaps_out = 48,
                bg_col = "rgb(111111)",
                dynamic_grid = false,
                fill_gaps = false,
                mru_sort = false,
                show_workspace_names = true,
                workspace_method = "first 1",
                skip_empty = false,
                max_workspace = 4,
                gesture_distance = 200,
                gesture_fingers = 3,
                gesture_direction = "up",
                show_cursor = true,
                drag_drop_enable = false,
                tile_rounding = 12,
                border_width = 2,
                border_color_current = "rgb(66ccff)",
            },
        },
    })

    -- Keyboard fallback for the overview, useful with an external mouse.
    hl.bind(mainMod .. " + G", function()
        hl.plugin.hyprexpo.expo("toggle")
    end)

    -- Swiping back down only closes the overview; unlike a second interactive
    -- overview gesture, it cannot open the view from an ordinary workspace.
    hl.gesture({
        fingers = 3,
        direction = "down",
        action = function()
            hl.plugin.hyprexpo.expo("off")
        end,
    })
end

if workspaceFeatureEnabled then
    hl.gesture({
        fingers = 3,
        direction = "horizontal",
        action = "workspace",
    })
end

-- Re-evaluate the profile after plugging or unplugging a display.  A reload
-- reconstructs the conditional bindings and gestures above; the short timer
-- lets a dock finish announcing all of its outputs first.
local function refreshWorkspaceProfile()
    hl.timer(function()
        -- Let the dock finish exposing its outputs, merge hidden laptop
        -- workspaces onto the focused physical page, then rebuild the
        -- workspace-only controls for the resulting topology.
        hl.exec_cmd(home .. "/.config/hypr/scripts/merge-laptop-workspaces.sh; hyprctl reload")
    end, { timeout = 750, type = "oneshot" })
end

hl.on("monitor.added", refreshWorkspaceProfile)
hl.on("monitor.removed", refreshWorkspaceProfile)

---- LOOK AND FEEL ----

hl.config({
    general = {
        gaps_in = 3,
        gaps_out = 5,
        border_size = 0,
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 8,
        blur = {
            enabled = true,
            size = 5,
            passes = 1,
            vibrancy = 0.2,
        },
        shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
        },
    },
    animations = {
        enabled = true,
    },
})

-- Old: bezier = easeOut,0.05,0.9,0.1,1.0
hl.curve("easeOut", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } })

-- Old: animation = windows,1,5,easeOut  (enabled, speed, style)
hl.animation({ leaf = "windows",    enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "border",     enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default" })

-- LAYOUT
hl.config({
    dwindle = { preserve_split = true },
})
hl.config({
    master = { new_status = "master" },
})

-- MISC
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

---- SPLIT-OUT FILES ----

require("keybinds")
require("rules")
