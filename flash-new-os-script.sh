#!/bin/bash

# Check if URL is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <url>"
    exit 1
fi

URL=$1
TMP_DIR=$(mktemp -d)
FILENAME="tollgate-os.bin"

# Download the file
echo "Downloading OS image from $URL..."
wget -O "$TMP_DIR/$FILENAME" "$URL"
if [ $? -ne 0 ]; then
    echo "Failed to download file"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Copy file to router
echo "Copying OS image to router..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$TMP_DIR/$FILENAME" "root@192.168.1.1:/root/$FILENAME"
if [ $? -ne 0 ]; then
    echo "Failed to copy file to router"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Clean up temp directory
rm -rf "$TMP_DIR"

# Execute sysupgrade
echo "Initiating system upgrade..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.1.1 "sysupgrade -n /root/$FILENAME"


