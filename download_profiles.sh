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
MAX_RETRIES=3

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
  
  # Validate URL exists before attempting download
  if ! curl --head --silent --fail "$url" > /dev/null; then
    echo "❌ URL does not exist or is unreachable: $url"
    rm -rf "$target_dir"
    return 1
  fi
  
  # Download with retries
  for ATTEMPT in $(seq 1 $MAX_RETRIES); do
    echo "  • Download attempt $ATTEMPT of $MAX_RETRIES"
    
    if curl -s -f -o "$output_file" "$url"; then
      # Validate downloaded file
      if [ -s "$output_file" ] && grep -q "\"profiles\":" "$output_file"; then
        # Count the number of profiles
        local profile_count=$(grep -o "\"target\":" "$output_file" | wc -l)
        echo "✅ Downloaded ${platform}/${target} - ${profile_count} device profiles"
        return 0
      else
        echo "⚠️ Downloaded file appears invalid. Retrying..."
        rm -f "$output_file"
      fi
    else
      echo "⚠️ Download attempt $ATTEMPT failed"
    fi
    
    # Only sleep if we're going to retry
    if [ "$ATTEMPT" -lt "$MAX_RETRIES" ]; then
      sleep 5
    fi
  done
  
  echo "❌ Failed to download ${platform}/${target} after $MAX_RETRIES attempts"
  # Clean up empty directory
  rm -rf "$target_dir"
  return 1
}

SUCCESS_COUNT=0
FAILURE_COUNT=0

# If specific platform provided, only download that one
if [ -n "$SPECIFIC_PLATFORM" ]; then
  # Split into platform and target
  PLATFORM=$(echo $SPECIFIC_PLATFORM | cut -d'/' -f1)
  TARGET=$(echo $SPECIFIC_PLATFORM | cut -d'/' -f2)
  
  if download_platform "$PLATFORM" "$TARGET" "$VERSION"; then
    SUCCESS_COUNT=$((SUCCESS_COUNT+1))
  else
    FAILURE_COUNT=$((FAILURE_COUNT+1))
  fi
else
  # Download all common platforms
  for PLATFORM_TARGET in "${COMMON_PLATFORMS[@]}"; do
    # Split into platform and target
    PLATFORM=$(echo $PLATFORM_TARGET | cut -d'/' -f1)
    TARGET=$(echo $PLATFORM_TARGET | cut -d'/' -f2)
    
    if download_platform "$PLATFORM" "$TARGET" "$VERSION"; then
      SUCCESS_COUNT=$((SUCCESS_COUNT+1))
    else
      FAILURE_COUNT=$((FAILURE_COUNT+1))
    fi
  done
fi

echo ""
echo "📊 Summary: Profiles downloaded to ${BASE_DIR}"
echo "  • Successful downloads: $SUCCESS_COUNT"
echo "  • Failed downloads: $FAILURE_COUNT"

PROFILE_COUNT=$(find "$BASE_DIR" -name "profiles.json" | wc -l)
if [ "$PROFILE_COUNT" -eq 0 ]; then
  echo "❌ ERROR: No profiles were downloaded successfully!"
  exit 1
fi

find "$BASE_DIR" -name "profiles.json" | while read profile; do
  count=$(grep -o "\"target\":" "$profile" | wc -l)
  platform_path=${profile#$BASE_DIR/}
  platform_path=${platform_path%/profiles.json}
  printf "%-25s %3d devices\n" "$platform_path" "$count"
done

echo ""
echo "✨ Done! You can now use these profiles with the TollGate OS build system."