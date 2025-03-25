#!/bin/sh
# This script configures a new wireless interface on first boot

# Add a new wifi-iface section with the specified options
uci add wireless wifi-iface
uci set wireless.@wifi-iface[-1].device='radio0'
uci set wireless.@wifi-iface[-1].network='lan'
uci set wireless.@wifi-iface[-1].mode='ap'
uci set wireless.@wifi-iface[-1].name='tollgate_2g_open'
uci set wireless.@wifi-iface[-1].ssid='TollGate - Setup'
uci set wireless.@wifi-iface[-1].encryption='none'

uci commit wireless

uci add wireless wifi-iface
uci set wireless.@wifi-iface[-1].device='radio1'
uci set wireless.@wifi-iface[-1].network='lan'
uci set wireless.@wifi-iface[-1].mode='ap'
uci set wireless.@wifi-iface[-1].name='tollgate_5g_open'
uci set wireless.@wifi-iface[-1].ssid='TollGate - Setup'
uci set wireless.@wifi-iface[-1].encryption='none'

# Commit the changes to the wireless configuration
uci commit wireless

# Additional commands can be added here
echo "Wireless interfaces for 'TollGate - Setup' configured and applied on first boot."
