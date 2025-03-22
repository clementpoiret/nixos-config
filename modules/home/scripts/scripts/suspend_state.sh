#!/usr/bin/env bash

PID_FILE="/tmp/suspend-inhibit.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo '{"text": "", "tooltip": "Suspend inhibited", "class": "inhibited"}'
    else
        rm "$PID_FILE"
        echo '{"text": "", "tooltip": "Suspend allowed", "class": "allowed"}'
    fi
else
    echo '{"text": "", "tooltip": "Suspend allowed", "class": "allowed"}'
fi
