#!/bin/bash
# Display battery status

BATTERY_PATH="/sys/class/power_supply/BAT0"

if [ ! -d "$BATTERY_PATH" ]; then
    BATTERY_PATH="/sys/class/power_supply/BAT1"
fi

if [ ! -d "$BATTERY_PATH" ]; then
    echo "N/A"
    exit 0
fi

# Get battery percentage
CAPACITY=$(cat "$BATTERY_PATH/capacity")

# Get charging status
STATUS=$(cat "$BATTERY_PATH/status")

case "$STATUS" in
    "Charging")
        ICON="⚡"
        COLOR="#FFFF00"
        ;;
    "Discharging")
        ICON="🔋"
        if [ "$CAPACITY" -lt 20 ]; then
            COLOR="#FF0000"  # Red when low
        elif [ "$CAPACITY" -lt 50 ]; then
            COLOR="#FFFF00"  # Yellow when medium
        else
            COLOR="#00FF00"  # Green when good
        fi
        ;;
    "Full")
        ICON="☻"
        COLOR="#00FF00"
        ;;
    *)
        ICON="?"
        COLOR="#FFFFFF"
        ;;
esac

echo "${ICON} ${CAPACITY}%"
echo "${ICON} ${CAPACITY}%"
echo "$COLOR"
