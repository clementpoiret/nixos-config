#!/usr/bin/env bash

# Check if hyprsunset is running
pid=$(pgrep -x hyprsunset)

# Set temperature based on whether hyprsunset is running or not
if [ -z "$pid" ]; then
  # If hyprsunset is not running, default temperature is 6500K
  temperature=6500
else
  # If hyprsunset is running, temperature is 5700K
  temperature=5700
fi

# Format the output for Waybar with line breaks
formatted_output="Temperature: $temperature"

# Check if the temperature is greater than or equal to 6500K
if [ "$temperature" -ge 6500 ]; then
  # Output as JSON for Waybar, escaping newlines
  echo "{\"text\": \"\", \"tooltip\": \"$formatted_output\"}"
else
  # Otherwise, output a different icon for lower temperature
  echo "{\"text\": \"󰽥\", \"tooltip\": \"$formatted_output\"}"
fi
