read -rsp "Password: " keyringpass
export $(echo -n "$keyringpass" | gnome-keyring-daemon --replace --unlock)
unset keyringpass
