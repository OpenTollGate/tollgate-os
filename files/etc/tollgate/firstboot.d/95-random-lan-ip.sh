#!/bin/sh
# TollGate - Generate random LAN IP address on first boot

FLAG_FILE="/etc/tollgate/firstboot/lan_ip_randomized"
if [ -f "$FLAG_FILE" ]; then
    echo "LAN IP already randomized. Exiting."
    exit 0
fi

INSTALL_JSON="/etc/tollgate/install.json"
if [ -f "$INSTALL_JSON" ]; then
    IP_RANDOMIZED=$(jq -r '.ip_address_randomized' "$INSTALL_JSON")
    if [ "$IP_RANDOMIZED" != "false" ]; then
        echo "IP is already randomized or not set to false. Exiting."
        exit 0
    fi
else
    echo "install.json not found. Exiting."
    exit 1
fi

# Helper function to safely set UCI values with error handling
uci_safe_set() {
    local config="$1"
    local section="$2"
    local option="$3"
    local value="$4"
    
    # Check if the config exists
    if [ ! -f "/etc/config/$config" ]; then
        echo "Creating config: $config"
        touch "/etc/config/$config"
    fi
    
    # Check if the section exists
    if ! uci -q get "$config.$section" >/dev/null 2>&1; then
        # Section doesn't exist, try to create it
        if [[ "$section" == *"@"* ]]; then
            # For array sections like @dnsmasq[0], we need special handling
            # Extract the section type
            section_type=$(echo "$section" | cut -d'@' -f2 | cut -d'[' -f1)
            uci add "$config" "$section_type" >/dev/null 2>&1
        else
            # For named sections
            uci set "$config.$section=" >/dev/null 2>&1
        fi
    fi
    
    # Now set the option safely
    uci set "$config.$section.$option=$value" >/dev/null 2>&1
}

# Initialize random seed
RANDOM=$$$(date +%s)

# Randomly select one of the three private IP ranges:
# 1: 10.0.0.0/8
# 2: 172.16.0.0/12
# 3: 192.168.0.0/16
RANGE_SELECT=$((RANDOM % 3 + 1))

case $RANGE_SELECT in
    1)
        # 10.0.0.0/8 range
        OCTET1=10
        OCTET2=$((1 + RANDOM % 254))  # 1-254
        OCTET3=$((1 + RANDOM % 254))  # 1-254
        ;;
    2)
        # 172.16.0.0/12 range (172.16.x.x - 172.31.x.x)
        OCTET1=172
        OCTET2=$((RANDOM % 16 + 16))  # 16-31
        OCTET3=$((RANDOM % 256))
        ;;
    3)
        # 192.168.0.0/16 range
        OCTET1=192
        OCTET2=168
        OCTET3=$((RANDOM % 256))
        ;;
esac

# Avoid common third octets in the 192.168.x.x range to reduce conflicts
if [ $OCTET1 -eq 192 ] && [ $OCTET2 -eq 168 ]; then
    while [ $OCTET3 -eq 0 ] || [ $OCTET3 -eq 1 ] || [ $OCTET3 -eq 100 ]; do
        OCTET3=$((RANDOM % 256))
    done
fi

# Construct the random IP with last octet as 1
RANDOM_IP="$OCTET1.$OCTET2.$OCTET3.1"
echo "Setting random LAN IP to: $RANDOM_IP"

# Update network config using UCI
uci_safe_set network lan ipaddr "$RANDOM_IP"
uci commit network

# Update hosts file
if grep -q "status.client" /etc/hosts; then
    sed -i "s/.*status\.client/$RANDOM_IP status.client/" /etc/hosts
else
    echo "$RANDOM_IP status.client" >> /etc/hosts
fi

# NoDogSplash config check and update (only if installed)
if [ -f "/etc/config/nodogsplash" ]; then
    if uci -q get nodogsplash.@nodogsplash[0] >/dev/null; then
        echo "NoDogSplash detected, would update its config if needed"
    fi
fi

# Also update the default gateway and broadcast address accordingly
NETMASK="255.255.255.0"  # Using standard /24 subnet
uci_safe_set network lan netmask "$NETMASK"

# Calculate subnet information for correct operation
BROADCAST="$OCTET1.$OCTET2.$OCTET3.255"
uci_safe_set network lan broadcast "$BROADCAST"

# Schedule network restart (safer than immediate restart during boot)
(sleep 5 && /etc/init.d/network restart && 
 [ -f "/etc/init.d/nodogsplash" ] && /etc/init.d/nodogsplash restart) &

# Update install.json with the new random IP
jq '.ip_address_randomized = "'"$RANDOM_IP"'"' "$INSTALL_JSON" > "$INSTALL_JSON.tmp" && mv "$INSTALL_JSON.tmp" "$INSTALL_JSON"

# Create flag file
touch "$FLAG_FILE"

exit 0