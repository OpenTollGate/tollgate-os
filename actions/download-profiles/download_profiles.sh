#!/bin/bash

# Script to download OpenWRT profiles for a specific version
# Usage: ./download_profiles.sh [version] [platform/target] [output-dir]
# Examples: 
#   ./download_profiles.sh 23.05.5 ramips/mt7621 custom_profiles

# Process arguments
VERSION="${1:-23.05.5}"
SPECIFIC_PLATFORM="${2:-}"
OUTPUT_DIR="${3:-external_profiles}"

# Set paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
WORKSPACE_DIR="${GITHUB_WORKSPACE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MAX_RETRIES=3

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
BASE_DIR="${WORKSPACE_DIR}/${OUTPUT_DIR}/${VERSION}"
mkdir -p "$BASE_DIR"

echo "🔍 Downloading OpenWRT profiles for version ${VERSION}..."
echo "📁 Saving to: ${BASE_DIR}"

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
        local profile_count=$(grep -o "\"titles\":" "$output_file" | wc -l)
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

# Function to generate id-to-name mapping for a profile
generate_device_mapping() {
  local profile_file=$1
  local output_file="${profile_file%.json}-mapping.txt"
  
  echo "📝 Generating device ID to name mapping for $(basename $(dirname "$profile_file"))/$(basename $(dirname $(dirname "$profile_file")))"
  
  # Check if profile file exists and is valid JSON
  if [ ! -f "$profile_file" ] || ! jq empty "$profile_file" 2>/dev/null; then
    echo "❌ Invalid profile file: $profile_file"
    return 1
  fi
  
  # Extract all profile IDs
  local ids=$(jq -r '.profiles | keys[]' "$profile_file")
  
  # Create the mapping file
  echo "# Device ID to Name mapping" > "$output_file"
  echo "# Format: device_id | vendor | model | full_name" >> "$output_file"
  echo "# Generated from: $profile_file" >> "$output_file"
  echo "# Generated on: $(date)" >> "$output_file"
  echo "" >> "$output_file"
  
  # For each ID, get the vendor and model name
  echo "$ids" | while read -r id; do
    vendor=$(jq -r --arg id "$id" '.profiles[$id].titles[0].vendor // "Unknown"' "$profile_file")
    model=$(jq -r --arg id "$id" '.profiles[$id].titles[0].model // "Unknown"' "$profile_file")
    variant=$(jq -r --arg id "$id" '.profiles[$id].titles[0].variant // ""' "$profile_file")
    
    # Construct full name
    if [ -n "$variant" ] && [ "$variant" != "null" ]; then
      full_name="$vendor $model ($variant)"
    else
      full_name="$vendor $model"
    fi
    
    # Add to mapping file
    echo "$id | $vendor | $model | $full_name" >> "$output_file"
  done
  
  echo "✅ Generated mapping file: $output_file"
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
    generate_device_mapping "${BASE_DIR}/${PLATFORM}/${TARGET}/profiles.json"
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
      generate_device_mapping "${BASE_DIR}/${PLATFORM}/${TARGET}/profiles.json"
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

echo ""
echo "📋 Device count by platform:"
find "$BASE_DIR" -name "profiles.json" | while read profile; do
  count=$(jq '.profiles | length' "$profile")
  platform_path=${profile#$BASE_DIR/}
  platform_path=${platform_path%/profiles.json}
  printf "%-25s %3d devices\n" "$platform_path" "$count"
done

# Create a summary file with quick device search capability
SUMMARY_FILE="${BASE_DIR}/device-search.txt"
echo "# OpenWrt Device Search Helper" > "$SUMMARY_FILE"
echo "# Version: $VERSION" >> "$SUMMARY_FILE"
echo "# Generated: $(date)" >> "$SUMMARY_FILE"
echo "# Format: device_id | platform/target | vendor | model" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

find "$BASE_DIR" -name "profiles.json" | while read profile; do
  platform_path=${profile#$BASE_DIR/}
  platform_path=${platform_path%/profiles.json}
  
  jq -r '.profiles | keys[]' "$profile" | while read id; do
    vendor=$(jq -r --arg id "$id" '.profiles[$id].titles[0].vendor // "Unknown"' "$profile")
    model=$(jq -r --arg id "$id" '.profiles[$id].titles[0].model // "Unknown"' "$profile")
    echo "$id | $platform_path | $vendor | $model" >> "$SUMMARY_FILE"
  done
done

echo ""
echo "📝 Created device search helper: $SUMMARY_FILE"
echo ""
echo "✨ Done! You can now use these profiles with the TollGate OS build system."
echo ""
echo "🔎 To find a device ID for a specific model, use:"
echo "   grep -i \"your-model-name\" \"$SUMMARY_FILE\""

# For GitHub Actions - set profile count output variable
if [ -n "$GITHUB_OUTPUT" ]; then
  echo "count=$PROFILE_COUNT" >> $GITHUB_OUTPUT
fi