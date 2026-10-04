-- ~/.config/hypr/keybinds.lua
-- Migrated from keybinds.conf
-- Docs: https://wiki.hypr.land/Configuring/Basics/Binds/
--       https://wiki.hypr.land/Configuring/Basics/Dispatchers/

local home = os.getenv("HOME")

-- Launchers
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("sh -c 'if pgrep -x rofi >/dev/null; then pkill -x rofi; else exec \"$HOME/.config/hypr/scripts/rofi.sh\" -show drun; fi'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser))


hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind("SUPER + Tab", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + GRAVE", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/logout-menu.sh"))
-- The picker is a toggle.  Launching Quickshell directly creates another
-- overlay each time, which leaves stacked selectors behind.
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/toggle-hyprquickpaper.sh"))

hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }))

hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/opacity.sh"))

-- Toggle waybar
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("sh -c 'pgrep -x waybar >/dev/null && pkill waybar || nohup waybar >/dev/null 2>&1 &'"))

-- Screenshots
hl.bind(mainMod .. " + Delete", hl.dsp.exec_cmd("grim " .. home .. "/Pictures/$(date +%s).png"))

-- Clipboard
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(
    "sh -c 'if pgrep -x rofi >/dev/null; then pkill -x rofi; else cliphist list | \"$HOME/.config/hypr/scripts/rofi.sh\" -dmenu -p \"\" | cliphist decode | wl-copy; fi'"
))

-- Toggle window Center and rezise
hl.bind(mainMod .. " + Space", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))

    local w = hl.get_active_window()
    if w ~= nil and w.floating then
        local mon = hl.get_active_monitor()
        if mon ~= nil then
            -- Monitor dimensions are physical pixels, but window geometry uses
            -- Hyprland's logical coordinates.  This matters on the 1.5-scale
            -- laptop panel (1920x1080 physical, 1280x720 logical).
            local scale = mon.scale or 1
            local logical_w = mon.width / scale
            local logical_h = mon.height / scale
            local target_w = math.floor(logical_w * 0.7)
            local target_h = math.floor(logical_h * 0.7)

            -- absolute resize (relative = false), not a delta
            hl.dispatch(hl.dsp.window.resize({ x = target_w, y = target_h, relative = false }))

            local mon_x = mon.x or 0
            local mon_y = mon.y or 0
            local target_x = mon_x + math.floor((logical_w - target_w) / 2)
            local target_y = mon_y + math.floor((logical_h - target_h) / 2)

            -- absolute move to the centered position
            hl.dispatch(hl.dsp.window.move({ x = target_x, y = target_y, relative = false }))
        end
    end
end)

-- Mouse move/resize (confirmed pattern from the official example config)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- VERIFY: exit dispatcher. Docs explicitly say to double check the exit
-- dispatcher call when moving to Lua.
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())

-- Focus (H/J/K/L = left/down/up/right, vim-style, matching your original)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))

-- VERIFY: move active window within layout (old `movewindow` dispatcher).
-- Confirmed pattern is hl.dsp.window.move({ workspace = N }) for sending to a
-- workspace (used below) - the direction-swap variant isn't shown in the
-- official example, so double check this fires like the old movewindow did.
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "up" }))

-- On the laptop, retain the regular in-layout swap whenever there is a window
-- in the requested horizontal direction.  Only an edge move -- where there is
-- nothing left or right to swap with -- sends the window to the neighbouring
-- workspace.  Clamp that destination so neither edge can create workspace 0
-- or 5.  When docked, retain the previous layout-movement behaviour because
-- virtual workspaces are deliberately disabled in that profile.
if workspaceFeatureEnabled then
    local function hasWindowInDirection(window, workspace, direction)
        if window.floating then
            return true
        end

        local window_center_x = window.at.x + (window.size.x / 2)

        for _, candidate in ipairs(hl.get_workspace_windows(workspace)) do
            if candidate.address ~= window.address and not candidate.floating then
                local candidate_center_x = candidate.at.x + (candidate.size.x / 2)
                if (direction == "left" and candidate_center_x < window_center_x)
                    or (direction == "right" and candidate_center_x > window_center_x) then
                    return true
                end
            end
        end

        return false
    end

    local function moveActiveWindowHorizontally(direction, offset)
        local workspace = hl.get_active_workspace()
        local window = hl.get_active_window()
        if workspace == nil or window == nil then
            return
        end

        if hasWindowInDirection(window, workspace, direction) then
            hl.dispatch(hl.dsp.window.move({ direction = direction }))
            return
        end

        local current = tonumber(workspace.name)
        if current == nil then
            return
        end

        local target = math.max(1, math.min(4, current + offset))
        if target ~= current then
            hl.dispatch(hl.dsp.window.move({ workspace = target }))
        end
    end

    hl.bind(mainMod .. " + SHIFT + Left", function()
        moveActiveWindowHorizontally("left", -1)
    end)
    hl.bind(mainMod .. " + SHIFT + Right", function()
        moveActiveWindowHorizontally("right", 1)
    end)
else
    hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "left" }))
    hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))
end

-- VERIFY: resize active window by pixel delta (old `resizeactive`, repeating
-- while held via `binde`). Param names guessed as x/y - confirm with hyprctl eval.
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -40, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 40, y = 0 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -40 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 40 }), { repeating = true })

-- Workspaces are laptop-only.  When docked, the physical displays are used
-- directly, so these bindings must not create or switch virtual spaces.
if workspaceFeatureEnabled then
    for i = 1, 4 do
        local key = i
        hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
        hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
    end
end

-- Media keys (confirmed pattern from the official example config)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

-- Laptop-panel brightness (the Fn layer emits these XF86 keys, not a separate
-- Fn modifier).  Target the backlight class so external-display controls and
-- keyboard LEDs are never changed by these bindings.
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl --class=backlight set 5%-"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl --class=backlight set 5%+"), { locked = true, repeating = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
