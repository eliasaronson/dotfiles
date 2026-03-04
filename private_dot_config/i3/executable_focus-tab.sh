#!/bin/bash
# focus-tab.sh - Focus tab N in current tabbed container
# Works on both i3 and Sway
TAB_NUM=$1

if [ "$SWAYSOCK" ]; then
    MSG_CMD=swaymsg
else
    MSG_CMD=i3-msg
fi

$MSG_CMD -t get_tree | jq -r --argjson n "$TAB_NUM" '
  recurse(.nodes[], .floating_nodes[]) |
  select(.nodes[]?.focused == true or .focused == true) |
  .nodes[$n - 1].id // empty
' | head -1 | xargs -I{} $MSG_CMD "[con_id={}] focus"
