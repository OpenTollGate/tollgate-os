#!/bin/sh

# This script extracts the tollgate-module-basic-go package, removes the conflicting banner,
# and repacks it to avoid collisions with base-files

set -e  # Exit on any error

PACKAGE_NAME="tollgate-module-basic-go"
WORKDIR="/tmp/fix-banner"
PACKAGE_FILE=""

echo "Finding the package file for $PACKAGE_NAME..."
# Find the package file in the typical OpenWrt packages directory
PACKAGE_FILE=$(find . -name "${PACKAGE_NAME}_*.ipk" -type f | head -n 1)

if [ -z "$PACKAGE_FILE" ]; then
    echo "ERROR: Could not find the package file for $PACKAGE_NAME"
    exit 1
fi

echo "Found package: $PACKAGE_FILE"

# Create working directory
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "Extracting package..."
tar -xzf "$PACKAGE_FILE"

if [ -f "./data.tar.gz" ]; then
    # Extract data archive
    mkdir -p data
    tar -xzf "./data.tar.gz" -C data

    # Remove the conflicting banner file
    if [ -f "./data/etc/banner" ]; then
        echo "Removing conflicting banner file..."
        mv "./data/etc/banner" "./data/etc/banner.tollgate"
        
        # Rebuild the data archive
        cd data
        tar -czf "../data.tar.gz" ./*
        cd ..
        
        # Rebuild the package
        NEW_PACKAGE="${PACKAGE_FILE%.ipk}-fixed.ipk"
        tar -czf "$NEW_PACKAGE" ./control.tar.gz ./data.tar.gz ./debian-binary
        
        echo "Created fixed package: $NEW_PACKAGE"
        echo "You can now use this package instead of the original."
    else
        echo "No banner file found in the package. No fix needed."
    fi
else
    echo "ERROR: Package extraction failed, could not find data archive."
fi

# Return to original directory
cd - > /dev/null

echo "Done."