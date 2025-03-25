#!/bin/sh
# This script configures wireless interfaces/devices on first boot

uci set wireless.@wifi-iface["default_radio0"].name='tollgate_2g_open'
uci set wireless.@wifi-iface["default_radio0"].ssid='TollGate - Setup'
uci set wireless.@wifi-iface["default_radio0"].encryption='none'

uci set wireless.@wifi-iface["default_radio1"].name='tollgate_5g_open'
uci set wireless.@wifi-iface["default_radio1"].ssid='TollGate - Setup'
uci set wireless.@wifi-iface["default_radio1"].encryption='none'

# Enable wireless interfaces
uci set wireless.@wifi-device["radio0"].disabled='0'
uci set wireless.@wifi-device["radio1"].disabled='0'

# Commit the changes to the wireless configuration
uci commit wireless

# Additional commands can be added here
echo "Wireless radios enabled, interfaces for 'TollGate - Setup' configured and applied on first boot."
