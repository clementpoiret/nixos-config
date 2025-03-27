#!/usr/bin/env bash

current=$(fw-fanctrl print current | rg "Strategy in use: '(.+)'" -r '$1')

case "$current" in
    laziest)
        next="lazy"
        ;;
    lazy)
        next="medium"
        ;;
    medium)
        next="agile"
        ;;
    agile)
        next="very-agile"
        ;;
    very-agile)
        next="deaf"
        ;;
    deaf)
        next="aeolus"
        ;;
    aeolus)
        next="laziest"
        ;;
    *)
        # Default if current strategy is unknown
        next="lazy"
        ;;
esac

fw-fanctrl use "$next"

echo "Fan control strategy changed from '$current' to '$next'"
