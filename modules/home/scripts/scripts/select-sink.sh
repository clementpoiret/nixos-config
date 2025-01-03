#!/usr/bin/env bash

# Parse pactl output and get sinks with their names
get_sinks() {
  pactl list sinks |
    awk '/^Sink/ {sink=1; next} 
         sink && /Name:/ {name=$2}
         sink && /Description:/ {print name "\t" substr($0,index($0,$2)); sink=0}'
}

# Format output for fuzzel
format_for_fuzzel() {
  while IFS=$'\t' read -r name desc; do
    # Skip empty lines
    [ -z "$name" ] && continue

    # Check if it's the default sink
    if [ "$(pactl get-default-sink)" = "$name" ]; then
      echo "→ $desc - Default"
    else
      echo "$desc"
    fi
  done
}

# Get formatted sinks
sinks=$(get_sinks)
output=$(echo -e "$sinks" | format_for_fuzzel)

# Show fuzzel menu
selected=$(echo -e "$output" | fuzzel --dmenu \
  --width=50 \
  --prompt="Select Audio Output: ")

# Exit if user cancelled
[ -z "$selected" ] && exit 0

# Remove "→" and "- Default" if present
selected=$(echo "$selected" | sed 's/^→ //' | sed 's/ - Default$//')

# Find the sink name for the selected description
sink_name=$(echo -e "$sinks" | awk -F'\t' -v desc="$selected" '$2 == desc {print $1}')

# Set the selected sink as default
[ -n "$sink_name" ] && pactl set-default-sink "$sink_name"
