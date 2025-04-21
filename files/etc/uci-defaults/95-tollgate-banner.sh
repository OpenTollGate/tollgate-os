#!/bin/sh

# This script properly merges the TollGate banner with OpenWRT banner
# instead of having packages overwrite each other's files

# The script runs on first boot after packages are installed

if [ -f /etc/banner.tollgate ]; then
  # Save original banner if it exists and we haven't already
  if [ -f /etc/banner ] && [ ! -f /etc/banner.openwrt ]; then
    cp /etc/banner /etc/banner.openwrt
  fi
  
  # Create a merged banner with both OpenWRT and TollGate banners
  {
    echo "----------------------------------------"
    echo "           TOLLGATE OS"
    echo "  Based on OpenWRT $(cat /etc/openwrt_release | grep DISTRIB_RELEASE | cut -d"'" -f2)"
    echo "----------------------------------------"
    echo ""
    cat /etc/banner.tollgate
    echo ""
    echo "----------------------------------------"
    echo "         OpenWRT Information"
    echo "----------------------------------------"
    cat /etc/banner.openwrt
  } > /etc/banner
  
  echo "TollGate banner merged with OpenWRT banner"
fi

exit 0