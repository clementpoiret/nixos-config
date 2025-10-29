#!/usr/bin/env nu

const STATE_FILE = "/tmp/dunst-urgency-filter-state"

# Get the current filter state
def "main status" [] {
  if ($STATE_FILE | path exists) {
    open $STATE_FILE | str trim
  } else {
    "false"
  }
}

# Toggle the urgency filters
def "main toggle" [] {
  let current = main status
  let new_state = if $current == "true" { "false" } else { "true" }
  
  $new_state | save -f $STATE_FILE
  
  dunstctl rule filter-low toggle
  dunstctl rule filter-normal toggle
  
  print $"Urgency filters: ($new_state)"
}

# Get waybar JSON output
def "main waybar" [] {
  let state = main status
  let alt = if $state == "true" { "filtered" } else { "normal" }
  
  {alt: $alt} | to json --raw
}

# Initialize the filter state (disabled by default)
def "main init" [] {
  "false" | save -f $STATE_FILE
  
  dunstctl rule filter-low disable
  dunstctl rule filter-normal disable
  
  print "Urgency filters initialized (disabled)"
}

def main [] {
  print "Usage: dunst-dnd <command>"
  print ""
  print "Commands:"
  print "  status  - Get current filter state (true/false)"
  print "  toggle  - Toggle urgency filters on/off"
  print "  waybar  - Output JSON for waybar module"
  print "  init    - Initialize filters as disabled"
}
