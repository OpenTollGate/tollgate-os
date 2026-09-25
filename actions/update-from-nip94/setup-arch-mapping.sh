#!/bin/bash

# This script prepares the architecture mapping for NIP-94 events processing
# It ensures that architecture names like x86_64 are properly handled

# Parameters:
# $1 - Path to the architecture_mapping.json file
# $2 - Path to store the processed events

set -euo pipefail

ARCH_MAPPING_FILE="$1"
EVENTS_DIR="$2"

echo "Setting up architecture mapping from $ARCH_MAPPING_FILE"

# Create events directory if it doesn't exist
mkdir -p "$EVENTS_DIR"

# Check if architecture mapping file exists
if [ -f "$ARCH_MAPPING_FILE" ]; then
    echo "Using architecture mapping from: $ARCH_MAPPING_FILE"
    
    # Copy the mapping file to the events directory for reference
    cp "$ARCH_MAPPING_FILE" "$EVENTS_DIR/architecture_mapping.json"
    
    # Create a simple lookup file for shell script use
    jq -r '.mappings | to_entries[] | .key + " " + .value' "$ARCH_MAPPING_FILE" > "$EVENTS_DIR/arch_lookup.txt"
    jq -r '.platform_mappings | to_entries[] | .key + " " + .value' "$ARCH_MAPPING_FILE" >> "$EVENTS_DIR/arch_lookup.txt"
    
    # Add default mapping
    DEFAULT_ARCH=$(jq -r '.default' "$ARCH_MAPPING_FILE")
    echo "default $DEFAULT_ARCH" >> "$EVENTS_DIR/arch_lookup.txt"
    
    echo "Architecture mapping setup complete"
else
    echo "Warning: Architecture mapping file not found at $ARCH_MAPPING_FILE"
    echo "Creating default mapping..."
    
    # Create a basic default mapping
    cat > "$EVENTS_DIR/arch_lookup.txt" << EOF
x86_64 x86_64
aarch64_generic aarch64_cortex-a53
mips_24kc mips_24kc
mipsel_24kc mipsel_24kc
ramips_mt7621 mipsel_24kc
default aarch64_cortex-a53
EOF

    echo "Default architecture mapping created"
fi

# Create helper function to find architecture mapping
cat > "$EVENTS_DIR/get_arch_mapping.sh" << 'EOF'
#!/bin/bash

# This helper script finds the appropriate architecture mapping for a given architecture string
# Usage: ./get_arch_mapping.sh arch_name
#
# For example:
#   ./get_arch_mapping.sh x86_64      # Returns x86_64
#   ./get_arch_mapping.sh ramips      # May return mipsel_24kc based on mappings

set -euo pipefail

ARCH="$1"
LOOKUP_FILE="$(dirname "$0")/arch_lookup.txt"

# Sanitize input by replacing any slashes with underscores
ARCH_SAFE=$(echo "$ARCH" | tr '/' '_')

# First look for exact match
MAPPING=$(grep -E "^${ARCH_SAFE} " "$LOOKUP_FILE" | awk '{print $2}' || true)

if [ -z "$MAPPING" ]; then
    # Try partial match by extracting platform
    PLATFORM=$(echo "$ARCH_SAFE" | cut -d'_' -f1)
    MAPPING=$(grep -E "^${PLATFORM}[_ ]" "$LOOKUP_FILE" | awk '{print $2}' || true)
    
    # If still not found, use default
    if [ -z "$MAPPING" ]; then
        MAPPING=$(grep "^default " "$LOOKUP_FILE" | awk '{print $2}')
    fi
fi

echo "$MAPPING"
EOF

# Make the helper script executable
chmod +x "$EVENTS_DIR/get_arch_mapping.sh"

echo "Architecture mapping helper script created at $EVENTS_DIR/get_arch_mapping.sh"
echo "Usage: ./get_arch_mapping.sh architecture_name"