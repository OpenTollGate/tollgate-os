#!/bin/bash

# Script to download OpenWRT profiles for a specific version
# Usage: ./download_profiles.sh [version] [platform/target]
# Examples: 
#   ./download_profiles.sh                      # Download for default version (23.05.5)
#   ./download_profiles.sh 23.05.5              # Download for specific version
#   ./download_profiles.sh 23.05.5 ramips/mt7621 # Download specific platform/target for version

# Default OpenWRT version
DEFAULT_VERSION="23.05.5"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Process arguments
VERSION=${1:-$DEFAULT_VERSION}
SPECIFIC_PLATFORM=${2:-""}

# Common platforms to download if no specific platform is provided
COMMON_PLATFORMS=(
  "ramips/mt7621"
  "ath79/generic"
  "ath79/nand"
  "mediatek/filogic"
  "ipq40xx/generic"
  "ipq806x/generic"
  "x86/64"
  "bcm27xx/bcm2711"  # Raspberry Pi 4
)

# Create base directory for this version
BASE_DIR="${SCRIPT_DIR}/external_profiles/${VERSION}"
mkdir -p "$BASE_DIR"

echo "🔍 Downloading OpenWRT profiles for version ${VERSION}..."

# Function to download a specific platform/target
download_platform() {
  local platform=$1
  local target=$2
  local version=$3
  
  # Create directory structure
  local target_dir="${BASE_DIR}/${platform}/${target}"
  mkdir -p "$target_dir"
  
  # Create URL and output filename
  local url="https://downloads.openwrt.org/releases/${version}/targets/${platform}/${target}/profiles.json"
  local output_file="${target_dir}/profiles.json"
  
  echo "⬇️ Downloading ${platform}/${target}..."
  
  # Download the file
  if curl -s -f -o "$output_file" "$url"; then
    # Count the number of profiles
    local profile_count=$(grep -o "\"target\":" "$output_file" | wc -l)
    echo "✅ Downloaded ${platform}/${target} - ${profile_count} device profiles"
    return 0
  else
    echo "❌ Failed to download ${platform}/${target}"
    # Clean up empty directory
    rm -rf "$target_dir"
    return 1
  fi
}

# If specific platform provided, only download that one
if [ -n "$SPECIFIC_PLATFORM" ]; then
  # Split into platform and target
  PLATFORM=$(echo $SPECIFIC_PLATFORM | cut -d'/' -f1)
  TARGET=$(echo $SPECIFIC_PLATFORM | cut -d'/' -f2)
  
  download_platform "$PLATFORM" "$TARGET" "$VERSION"
else
  # Download all common platforms
  for PLATFORM_TARGET in "${COMMON_PLATFORMS[@]}"; do
    # Split into platform and target
    PLATFORM=$(echo $PLATFORM_TARGET | cut -d'/' -f1)
    TARGET=$(echo $PLATFORM_TARGET | cut -d'/' -f2)
    
    download_platform "$PLATFORM" "$TARGET" "$VERSION"
  done
fi

echo ""
echo "📊 Summary: Profiles downloaded to ${BASE_DIR}"
find "$BASE_DIR" -name "profiles.json" | while read profile; do
  count=$(grep -o "\"target\":" "$profile" | wc -l)
  platform_path=${profile#$BASE_DIR/}
  platform_path=${platform_path%/profiles.json}
  printf "%-25s %3d devices\n" "$platform_path" "$count"
done

echo ""
echo "✨ Done! You can now use these profiles with the TollGate OS build system."