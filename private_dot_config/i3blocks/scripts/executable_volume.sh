#!/bin/bash
# Display volume level and mute status

# Get volume percentage
VOLUME=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1 | tr -d '%')

# Check if muted
MUTED=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -oP 'yes|no')

if [ "$MUTED" = "yes" ]; then
    echo "MUTE"
    echo "MUTE"
    echo "#FF0000"  # Red color
else
    echo "${VOLUME}%"
    echo "${VOLUME}%"
    
    # Color based on volume level
    if [ "$VOLUME" -gt 70 ]; then
        echo "#FF0000"  # Red for high volume
    elif [ "$VOLUME" -gt 40 ]; then
        echo "#FFFF00"  # Yellow for medium
    else
        echo "#00FF00"  # Green for low
    fi
fi
