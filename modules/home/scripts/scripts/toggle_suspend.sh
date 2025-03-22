#!/usr/bin/env bash

PID_FILE="/tmp/suspend-inhibit.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        rm "$PID_FILE"
    else
        rm "$PID_FILE"
    fi
else
    systemd-inhibit --what=sleep --mode=block sleep infinity &
    echo $! > "$PID_FILE"
fi
