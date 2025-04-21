#!/bin/bash

# Script to build OpenWrt image in two steps to avoid the banner conflict
# Step 1: Build without tollgate-module-basic-go
# Step 2: Add tollgate-module-basic-go separately

set -e  # Exit on any error

# Variables - adjust these to match your environment
IMAGE_BUILDER_DIR="openwrt-imagebuilder-23.05.5-ath79-nand.Linux-x86_64"
PROFILE="netgear_wndr4300"  # Change this to your router profile
PACKAGES="luci luci-ssl"     # Add your other packages here
TOLLGATE_PKG="tollgate-module-basic-go"

cd $IMAGE_BUILDER_DIR

echo "=== Starting two-step build process ==="

echo "Step 1: Building base images without $TOLLGATE_PKG..."
make image PROFILE="$PROFILE" PACKAGES="$PACKAGES -$TOLLGATE_PKG" || {
    echo "Error in Step 1 build!"
    exit 1
}

echo "Step 2: Building images with $TOLLGATE_PKG..."
make image PROFILE="$PROFILE" PACKAGES="$PACKAGES $TOLLGATE_PKG" || {
    echo "Warning: Second build with $TOLLGATE_PKG failed."
    echo "The first build without $TOLLGATE_PKG should still be available."
}

echo "=== Build process complete ==="
echo "Check the bin directory for your firmware images."
echo "The first build without $TOLLGATE_PKG should work even if the second build failed."