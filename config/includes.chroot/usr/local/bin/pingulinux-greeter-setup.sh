#!/bin/bash
#
# pingulinux-greeter-setup.sh  (als root, von LightDM vor dem Login-Bildschirm)
# Erkennt Tablets (Touchscreen oder Tablet-/Convertible-Gehaeuse) und schaltet
# dann die Bildschirmtastatur (onboard) im Login-Bildschirm automatisch ein.
# Auf normalen Rechnern bleibt sie nur ueber das Barrierefreiheits-Symbol erreichbar.

CONF=/etc/lightdm/lightdm-gtk-greeter.conf
tablet=0
grep -qi "touchscreen" /proc/bus/input/devices 2>/dev/null && tablet=1
case "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" in 30|31|32) tablet=1 ;; esac

[ -f "$CONF" ] || exit 0
sed -i '/^a11y-states=/d' "$CONF"
if [ "$tablet" = 1 ]; then
    sed -i '/^\[greeter\]/a a11y-states=+keyboard' "$CONF"
fi
exit 0
