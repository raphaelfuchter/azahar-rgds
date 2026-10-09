#!/bin/bash
# Installs the custom Azahar build and helper scripts on an RG DS running ROCKNIX(DS).
# Usage: device/install.sh <device-ip> <path-to-azahar-binary>
# Restarts EmulationStation once (it must not be running while system.cfg is edited).
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
scp "$D/emulationstation/azahar-features.xml" $H:/tmp/azahar-features.xml
ssh $H 'chmod +x /storage/.config/azahar/bin/real/azahar-rgds /storage/.config/azahar/bin/azahar-wrapper \
    /storage/.config/azahar/azahar-gexit /storage/.config/autostart/azahar-custom
  C=/storage/.config/azahar/qt-config.ini
  sed -i "s/^confirmClose=.*/confirmClose=false/; s/^confirmClose\\\\default=.*/confirmClose\\\\default=false/" $C
  # 3DS options in EmulationStation (Advanced game options), inside the azahar-sa core
  F=/storage/.config/emulationstation/es_features.cfg
  [ -f $F ] || cp /usr/config/emulationstation/es_features.cfg $F
  grep -q "name=\"optimized build\"" $F || awk "
    /<core name=\"azahar-sa\"/ { in_core = 1 }
    { print }
    in_core && /<features>/ { while ((getline l < \"/tmp/azahar-features.xml\") > 0) print l; in_core = 0 }
  " $F > $F.new && mv $F.new $F
  # Optimized build on by default; turn it off in ES (globally or per game) for the original Azahar
  S=/storage/.config/system/configs/system.cfg
  if ! grep -q "^3ds.optimized_build=" $S; then
    systemctl stop essway; echo "3ds.optimized_build=1" >> $S; systemctl start essway
  fi
  umount /usr/bin/azahar 2>/dev/null; /storage/.config/autostart/azahar-custom
  grep " /usr/bin/azahar " /proc/mounts && echo installed'
