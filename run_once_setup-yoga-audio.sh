#!/bin/bash
# NixOS handles this declaratively (modules/yoga-audio.nix in the flake) — skip there.
[ -e /etc/NIXOS ] && exit 0

# Lenovo Yoga Pro 9i Gen 9 speaker enablement. The speaker amplifiers are off by
# default on Linux (firmware bug), so sound needs this I2C initialization at boot
# and after every resume. Reproduces:
#   https://github.com/maximmaxim345/yoga_pro_9i_gen9_linux
# The init script auto-detects the model via DMI; this machine (83DN) uses the
# default I2C address/bus branch. Idempotent: overwrites files and re-enables.
set -euo pipefail

# 1. i2c-tools provides i2cset / i2cdetect
if ! dpkg -s i2c-tools &>/dev/null; then
    sudo apt update && sudo apt install -y i2c-tools
fi

# 2. Speaker init script (exact i2cset register writes from upstream)
sudo tee /usr/local/bin/2pa-byps.sh > /dev/null << 'SCRIPT'
#!/bin/bash

export TERM=linux

modprobe i2c-dev

laptop_model=$(</sys/class/dmi/id/product_name)
echo "Laptop model: $laptop_model"

find_i2c_bus() {
    local adapter_description="Synopsys DesignWare I2C adapter"
    local dw_count=$(i2cdetect -l | grep -c "$adapter_description")
    local bus_index=3
    [[ "$laptop_model" == "83L0" ]] && bus_index=2
    if [ "$dw_count" -lt "$bus_index" ]; then
        echo "Error: Less than $bus_index DesignWare I2C adapters found." >&2
        return 1
    fi
    local bus_number=$(i2cdetect -l | grep "$adapter_description" | awk '{print $1}' | sed 's/i2c-//' | sed -n "${bus_index}p")
    echo "$bus_number"
}

i2c_bus=$(find_i2c_bus)
if [ -z "$i2c_bus" ]; then
    echo "Error: Could not find the DesignWare I2C bus for the audio IC." >&2
    exit 1
fi
echo "Using I2C bus: $i2c_bus"

if [[ "$laptop_model" == "83BY" ]]; then
    i2c_addr=(0x39 0x38 0x3d 0x3b)
else
    i2c_addr=(0x3f 0x38)
fi

count=0
for value in "${i2c_addr[@]}"; do
    val=$((count % 2))
    i2cset -f -y "$i2c_bus" "$value" 0x00 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x7f 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x01 0x01
    i2cset -f -y "$i2c_bus" "$value" 0x0e 0xc4
    i2cset -f -y "$i2c_bus" "$value" 0x0f 0x40
    i2cset -f -y "$i2c_bus" "$value" 0x5c 0xd9
    i2cset -f -y "$i2c_bus" "$value" 0x60 0x10
    if [ $val -eq 0 ]; then
        i2cset -f -y "$i2c_bus" "$value" 0x0a 0x1e
    else
        i2cset -f -y "$i2c_bus" "$value" 0x0a 0x2e
    fi
    i2cset -f -y "$i2c_bus" "$value" 0x0d 0x01
    i2cset -f -y "$i2c_bus" "$value" 0x16 0x40
    i2cset -f -y "$i2c_bus" "$value" 0x00 0x01
    i2cset -f -y "$i2c_bus" "$value" 0x17 0xc8
    i2cset -f -y "$i2c_bus" "$value" 0x00 0x04
    i2cset -f -y "$i2c_bus" "$value" 0x30 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x31 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x32 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x33 0x01
    i2cset -f -y "$i2c_bus" "$value" 0x00 0x08
    i2cset -f -y "$i2c_bus" "$value" 0x18 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x19 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x1a 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x1b 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x28 0x40
    i2cset -f -y "$i2c_bus" "$value" 0x29 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x2a 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x2b 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x00 0x0a
    i2cset -f -y "$i2c_bus" "$value" 0x48 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x49 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x4a 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x4b 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x58 0x40
    i2cset -f -y "$i2c_bus" "$value" 0x59 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x5a 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x5b 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x00 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x02 0x00
    count=$((count + 1))
done
SCRIPT
sudo chmod +x /usr/local/bin/2pa-byps.sh

# 3. systemd service: runs at boot and after every sleep/resume
sudo tee /etc/systemd/system/yoga-16imh9-speakers.service > /dev/null << 'UNIT'
[Unit]
Description=Turn on speakers using i2c configuration
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
User=root
Type=oneshot
ExecStart=/bin/sh -c "/usr/local/bin/2pa-byps.sh | logger"

[Install]
WantedBy=multi-user.target sleep.target
Also=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
UNIT

# 4. Blacklist the codec power-save module that otherwise mutes the amps
echo "blacklist snd_hda_scodec_tas2781_i2c" \
    | sudo tee /etc/modprobe.d/disable-hda-power-save.conf > /dev/null

# 5. Enable + start now
sudo systemctl daemon-reload
sudo systemctl enable --now yoga-16imh9-speakers.service

echo "[INFO] Yoga speaker service installed and enabled."
echo "[INFO] Optional extras (manual): import an EasyEffects preset and the ICC"
echo "[INFO] display profile from the upstream repo for tuned sound/color."
