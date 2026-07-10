#!/bin/bash
# Battery monitoring daemon for i3
# Runs in background and checks battery status frequently

BATTERY_PATH="/sys/class/power_supply/BAT0"
if [ ! -d "$BATTERY_PATH" ]; then
    BATTERY_PATH="/sys/class/power_supply/BAT1"
fi

if [ ! -d "$BATTERY_PATH" ]; then
    echo "No battery found, exiting."
    exit 0
fi

# Thresholds
CRITICAL_LEVEL=10
LOW_LEVEL=15
VERY_LOW_LEVEL=5

# Track notification state to avoid spam
LAST_NOTIFICATION=""
CHECK_INTERVAL=60 # Check every 60 seconds

# Function to send notification only if state changed
send_notification() {
    local level=$1
    local message=$2
    local urgency=$3

    if [ "$LAST_NOTIFICATION" != "$level" ]; then
        notify-send -u "$urgency" "🔋 Battery $level" "$message"
        LAST_NOTIFICATION="$level"
    fi
}

while true; do
    # Read battery info
    CAPACITY=$(cat "$BATTERY_PATH/capacity" 2>/dev/null)
    STATUS=$(cat "$BATTERY_PATH/status" 2>/dev/null)

    # Only act if discharging
    if [ "$STATUS" = "Discharging" ]; then
        if [ "$CAPACITY" -le "$VERY_LOW_LEVEL" ]; then
            send_notification "CRITICAL" "Only ${CAPACITY}% remaining! System will suspend soon!" "critical"
            # Optional: Auto-suspend at very low battery
            # systemctl suspend
        elif [ "$CAPACITY" -le "$CRITICAL_LEVEL" ]; then
            send_notification "Critical" "${CAPACITY}% remaining. Plug in immediately!" "critical"
        elif [ "$CAPACITY" -le "$LOW_LEVEL" ]; then
            send_notification "Low" "${CAPACITY}% remaining. Please plug in soon." "normal"
        else
            LAST_NOTIFICATION="" # Reset when above low threshold
        fi
    else
        # Reset notification state when charging or full
        LAST_NOTIFICATION=""
    fi

    sleep $CHECK_INTERVAL
done
