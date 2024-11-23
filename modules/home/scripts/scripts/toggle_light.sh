#!/usr/bin/env bash
CURRENT_TEMP=$(pgrep -a hyprsunset | grep -o '\-t [0-9]*' | cut -d' ' -f2)
TEMP=6000

if [ -n "$CURRENT_TEMP" ]; then
  if [ "$CURRENT_TEMP" -eq "6000" ]; then
    TEMP=3000
  fi
fi

killall hyprsunset
sleep 0.1 # If I don't sleep a bit, it causes crashes
hyprsunset -t $TEMP &
