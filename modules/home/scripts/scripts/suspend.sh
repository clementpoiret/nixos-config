#!/usr/bin/env bash

swayidle -w \
  timeout 300 'hyprctl dispatch dpms off' \
  timeout 360 'hyprlock' \
  timeout 420 'loginctl suspend' \
  resume 'hyprctl dispatch dpms on' \
  before-sleep 'hyprlock'
