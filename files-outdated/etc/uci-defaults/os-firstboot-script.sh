#!/bin/sh
# This script configures wireless interfaces/devices on first boot
current_dns=$(uci -q get network.lan.dns)
if [ "$current_dns" = "127.0.0.1" ] || [ "$current_dns" = "::1" ] || [ -z "$current_dns" ]; then
    # Only change DNS if it's set to localhost or not set
    uci -q delete network.lan.dns
    uci add_list network.lan.dns='1.1.1.1'  # CloudFlare primary DNS
    uci add_list network.lan.dns='1.0.0.1'  # CloudFlare secondary DNS
fi
uci set network.lan.domain='lan'

uci commit network
