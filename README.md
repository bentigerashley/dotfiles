# Arch Linux dotfiles

Personal desktop configuration for an Arch Linux system running Hyprland.

## Included

- Hyprland, Hyprlock, and the scripts used by active key bindings
- Waybar and its GPU and power profile modules
- Kitty, Rofi, Quickshell HyprQuickPaper, and wlogout
- GTK 3 appearance settings and nwg-look preferences

## Dependencies

The configuration expects Hyprland 0.56.2, Waybar, Kitty, Rofi, Quickshell, wlogout, GTK 3, and the command-line tools referenced by the included settings and scripts.

The Hyprland overview uses a locally built Hyprexpo plugin at `~/.local/share/hyprexpo/hyprexpo.so`. Build it for the installed Hyprland version before using that feature; the compiled plugin is not included here.

## Apply the configuration

Review the files, back up any existing settings you want to keep, then copy the selected directories from `.config/` into your home `.config/` directory. These files describe one personal machine, so check the paths and dependencies before applying them elsewhere.

Wallpaper images are not included. The wallpaper scripts and picker expect images under `~/Pictures/Wallpapers`. Before the first login with this configuration, place a wallpaper at `~/Pictures/Wallpapers/w4.png` or update the default path in `.config/hypr/scripts/wallpaper.sh`; otherwise Hyprland exits back to the login screen. The Quickshell and wlogout settings currently contain `/home/bashley` paths; update those paths if your home directory differs.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for the copyright and permission notice.
