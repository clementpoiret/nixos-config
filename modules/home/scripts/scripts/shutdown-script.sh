#!/usr/bin/env zsh

respond="$(echo " Shutdown\n Restart\n Logout\n Cancel" | fuzzel --dmenu --lines=4 --width=10 --prompt='')"

if [ $respond = " Shutdown" ]
then
    echo "shutdown"
	shutdown now
elif [ $respond = " Restart" ]
then
    echo "restart"
    reboot
elif [ $respond = " Logout" ]
then
    echo "logout"
    loginctl terminate-user ""
fi
