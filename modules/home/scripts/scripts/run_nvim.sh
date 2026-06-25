#!/usr/bin/env bash

source /etc/set-environment
source /etc/profiles/per-user/"$(id -un)"/etc/profile.d/hm-session-vars.sh

nvim
