#!/bin/bash
# NixOS handles this declaratively (services.automatic-timezoned) — skip there.
[ -e /etc/NIXOS ] && exit 0

# Install the NetworkManager dispatcher that auto-sets the system timezone from
# IP geolocation whenever a connection comes up. Event-driven (no polling), and
# only changes when the detected zone actually differs. Needs no extra package
# (uses curl + timedatectl); the "tzupdate" in the name is just the filename.
set -euo pipefail

sudo tee /etc/NetworkManager/dispatcher.d/90-tzupdate > /dev/null << 'DISPATCH'
#!/bin/sh
# Auto-set the system timezone from IP geolocation, triggered by NetworkManager
# whenever a connection comes up. Event-driven (not periodic), so it only ever
# changes when you actually join a different network in a different place -- it
# never randomly flaps while you sit at home on the same connection.

ACTION="$2"

# Only react to a connection coming up or a connectivity change.
case "$ACTION" in
    up|connectivity-change) ;;
    *) exit 0 ;;
esac

# Ask an IP-geolocation service for the IANA zone name (e.g. Europe/Stockholm).
tz=$(curl -s --max-time 5 "http://ip-api.com/line/?fields=timezone")

# Guard against junk/empty responses: must look like Region/City AND exist.
case "$tz" in
    */*) ;;
    *) exit 0 ;;
esac
[ -f "/usr/share/zoneinfo/$tz" ] || exit 0

# Only change if it actually differs -- avoids needless churn and log spam.
current=$(timedatectl show -p Timezone --value 2>/dev/null)
[ "$tz" = "$current" ] && exit 0

timedatectl set-timezone "$tz"
logger -t tzupdate-nm "timezone changed: ${current:-unknown} -> $tz"
DISPATCH

sudo chmod +x /etc/NetworkManager/dispatcher.d/90-tzupdate
echo "[INFO] Installed 90-tzupdate NetworkManager dispatcher"
