#!/usr/bin/env nu
# Wallpaper picker for Hyprland using fuzzel
# Lists wallpapers recursively and applies selection via hyprpaper

let wall_dir = ([$env.HOME, "Pictures", "wallpapers"] | path join)

if not ($wall_dir | path exists) {
  notify-send "Error" $"Wallpaper directory not found: ($wall_dir)"
  exit 1
}

# List wallpapers and get relative paths
let wallpapers = (
  glob $"($wall_dir)/**/*.{png,jpg,jpeg,webp,bmp}" --no-dir
  | where {|p| ($p | path type) == "file" }
  | sort
  | path relative-to $wall_dir
)

if ($wallpapers | is-empty) {
  notify-send "Error" "No wallpapers found"
  exit 1
}

# Show in fuzzel and capture selection
let selected = (
  $wallpapers
  | str join "\n"
  | fuzzel --dmenu --prompt="Wallpaper: "
  | complete
)

# Exit if nothing selected (Escape pressed)
if $selected.exit_code != 0 or ($selected.stdout | str trim | is-empty) {
  exit 0
}

let selected_path = ($selected.stdout | str trim)
let full_path = ([$wall_dir, $selected_path] | path join)

# Preload the wallpaper
let preload_result = (
  hyprctl hyprpaper preload $full_path
  | complete
)

if $preload_result.exit_code != 0 {
  notify-send "Error" "Failed to preload wallpaper"
  exit 1
}

# Set the wallpaper (empty monitor name = all monitors)
let wallpaper_result = (
  hyprctl hyprpaper wallpaper $",($full_path)"
  | complete
)

if $wallpaper_result.exit_code != 0 {
  notify-send "Error" "Failed to set wallpaper"
  exit 1
}

# Optional: Unload unused wallpapers to free memory
sleep 500ms
hyprctl hyprpaper unload unused

notify-send "Wallpaper Changed" $selected_path
