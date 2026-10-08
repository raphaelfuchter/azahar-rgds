#!/bin/bash
# Installs the custom Azahar build and helper scripts on an RG DS running ROCKNIX(DS).
# Usage: device/install.sh <device-ip> <path-to-azahar-binary>
set -e
IP=${1:?device ip}; BIN=${2:?azahar binary}
D="$(dirname "$0")"
H=root@$IP
ssh $H 'mkdir -p /storage/.config/azahar/bin/real /storage/.config/autostart /storage/.config/profile.d'
scp "$BIN" $H:/storage/.config/azahar/bin/real/azahar-rgds
scp "$D/azahar/azahar-wrapper" $H:/storage/.config/azahar/bin/azahar-wrapper
scp "$D/azahar/azahar-gexit" $H:/storage/.config/azahar/azahar-gexit
scp "$D/autostart/azahar-custom" $H:/storage/.config/autostart/azahar-custom
scp "$D/profile.d/100-azahar-graceful-exit" $H:/storage/.config/profile.d/100-azahar-graceful-exit
ssh $H 'chmod +x /storage/.config/azahar/bin/real/azahar-rgds /storage/.config/azahar/bin/azahar-wrapper \
    /storage/.config/azahar/azahar-gexit /storage/.config/autostart/azahar-custom
  C=/storage/.config/azahar/qt-config.ini
  sed -i "s/^confirmClose=.*/confirmClose=false/; s/^confirmClose\\\\default=.*/confirmClose\\\\default=false/" $C
  S=/storage/.config/sway/config
  grep -q "azahar_emu.Azahar" $S || sed -i "/Secondary|/a for_window [app_id=\"org.azahar_emu.Azahar\" title=\"^(?!.*Secondary).*\$\"] move window to output DSI-2" $S
  umount /usr/bin/azahar 2>/dev/null; /storage/.config/autostart/azahar-custom
  grep " /usr/bin/azahar " /proc/mounts && echo installed'
