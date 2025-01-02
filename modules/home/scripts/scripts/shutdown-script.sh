#!/usr/bin/env bash

respond="$(echo -e " Shutdown\n Restart\n Suspend\n Logout\n Cancel" | fuzzel --dmenu --lines=5 --width=11 --prompt='')"

if [ "$respond" = " Shutdown" ]; then
    echo "shutdown"
    shutdown now
elif [ "$respond" = " Restart" ]; then
    echo "restart"
    reboot
elif [ "$respond" = " Suspend" ]; then
    echo "suspend"
    systemctl suspend
elif [ "$respond" = " Logout" ]; then
    echo "logout"
    loginctl terminate-user "$USER"
elif [ "$respond" = " Cancel" ]; then
    echo "cancel"
    exit 0
fi
