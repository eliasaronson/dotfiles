#!/bin/bash
# Save this as ~/.config/i3/autorandr_setup.sh

# Get the primary display
PRIMARY=$(xrandr | grep " connected primary" | cut -d' ' -f1)

# Get external display
EXTERNAL=$(xrandr | grep " connected" | grep -v "primary" | cut -d' ' -f1 | head -n1)

if [ -n "$EXTERNAL" ]; then
    # Get max resolution for each display
    PRIMARY_RES=$(xrandr | grep -A1 "^${PRIMARY} connected" | tail -n1 | awk '{print $1}')
    EXTERNAL_RES=$(xrandr | grep -A1 "^${EXTERNAL} connected" | tail -n1 | awk '{print $1}')

    # Place external monitor to the right of primary at max resolutions
    # xrandr --output $PRIMARY --mode $PRIMARY_RES --primary --output $EXTERNAL --mode $EXTERNAL_RES --right-of $PRIMARY
    # Place external monitor to the LEFT of primary at max resolutions
    xrandr --output $PRIMARY --mode $PRIMARY_RES --primary --output $EXTERNAL --mode $EXTERNAL_RES --left-of $PRIMARY

    # Wait a moment for xrandr to apply
    sleep 1

    # Move all workspaces to the external monitor
    for workspace in $(i3-msg -t get_workspaces | jq -r '.[].name'); do
        i3-msg "workspace $workspace; move workspace to output $EXTERNAL"
    done
else
    # Only primary display connected
    PRIMARY_RES=$(xrandr | grep -A1 "^${PRIMARY} connected" | tail -n1 | awk '{print $1}')
    xrandr --output $PRIMARY --mode $PRIMARY_RES --primary
fi
