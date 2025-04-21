#!/bin/bash

# Script to download OpenWRT profiles for a specific version or architecture
# Usage: ./download_profiles.sh [version] [platform/target] [output-dir]
# Examples: 
#   ./download_profiles.sh                      # Download for default version (23.05.5)
#   ./download_profiles.sh 23.05.5              # Download for specific version
#   ./download_profiles.sh 23.05.5 ramips/mt7621 # Download specific platform/target for version

# Process arguments
VERSION="${1:-23.05.5}"
SPECIFIC_PLATFORM="${2:-}"
OUTPUT_DIR="${3:-external_profiles}"
FORCE_DOWNLOAD="${4:-false}"

# Set paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
WORKSPACE_DIR="${GITHUB_WORKSPACE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MAX_RETRIES=3
MIN_EOL_DATE="2025-08-04"  # Minimum end-of-life date to consider a version supported

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

# Create base directory for profiles
mkdir -p "${WORKSPACE_DIR}/${OUTPUT_DIR}"

echo "🔍 Processing OpenWRT profiles..."

# Function to download a file with retries
download_with_retries() {
  local url=$1
  local output_file=$2
  local description=$3
  local max_retries=${4:-$MAX_RETRIES}
  
  echo "⬇️ Downloading ${description}..."
  
  # Validate URL exists before attempting download
  if ! curl --head --silent --fail "$url" > /dev/null; then
    echo "❌ URL does not exist or is unreachable: $url"
    return 1
  fi
  
  # Download with retries
  for ATTEMPT in $(seq 1 $max_retries); do
    echo "  • Download attempt $ATTEMPT of $max_retries"
    
    if curl -s -f -o "$output_file" "$url"; then
      # Validate downloaded file is not empty
      if [ -s "$output_file" ]; then
        echo "✅ Downloaded ${description}"
        return 0
      else
        echo "⚠️ Downloaded file is empty. Retrying..."
        rm -f "$output_file"
      fi
    else
      echo "⚠️ Download attempt $ATTEMPT failed"
    fi
    
    # Only sleep if we're going to retry
    if [ "$ATTEMPT" -lt $max_retries ]; then
      sleep 3
    fi
  done
  
  echo "❌ Failed to download ${description} after $max_retries attempts"
  return 1
}

# Function to get OpenWRT versions from endoflife.date API
get_openwrt_versions() {
  local api_url="https://endoflife.date/api/openwrt.json"
  local output_file="${WORKSPACE_DIR}/${OUTPUT_DIR}/openwrt_versions.json"
  
  if [ -f "$output_file" ] && [ "$FORCE_DOWNLOAD" != "true" ]; then
    local file_age=$(( $(date +%s) - $(stat -c %Y "$output_file" 2>/dev/null || stat -f %m "$output_file") ))
    # Only use cached version if less than 24 hours old
    if [ "$file_age" -lt 86400 ]; then
      echo "✅ Using cached OpenWRT version information (less than 24h old)"
      return 0
    fi
  fi
  
  if download_with_retries "$api_url" "$output_file" "OpenWRT version information"; then
    echo "✅ Updated OpenWRT version information"
    return 0
  else
    # If download failed but we have an existing file, use it
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
      echo "⚠️ Using older cached version information"
      return 0
    else
      echo "❌ Failed to get OpenWRT version information"
      return 1
    fi
  fi
}

# Function to find supported OpenWRT versions
find_supported_versions() {
  local versions_file="${WORKSPACE_DIR}/${OUTPUT_DIR}/openwrt_versions.json"
  
  if [ ! -f "$versions_file" ] || [ ! -s "$versions_file" ]; then
    echo "❌ No version information available"
    return 1
  fi
  
  echo "🔍 Finding supported OpenWRT versions..."
  echo "   Minimum end-of-life date: $MIN_EOL_DATE"
  
  # Parse the JSON file and find supported versions
  local supported_versions=()
  local current_date=$(date +%Y-%m-%d)
  
  # Process the JSON file to find versions that meet our criteria
  while read -r cycle release_date eol latest latest_release_date; do
    # Skip header lines or empty lines
    if [[ "$cycle" == "cycle" ]] || [[ -z "$cycle" ]]; then
      continue
    fi
    
    # Parse the values
    is_supported=false
    
    # Check if version is supported (eol is false or after our minimum date)
    if [[ "$eol" == "false" ]]; then
      is_supported=true
    elif [[ "$eol" > "$MIN_EOL_DATE" ]]; then
      is_supported=true
    fi
    
    if [[ "$is_supported" == "true" ]]; then
      supported_versions+=("$latest")
      echo "✅ Version $latest (cycle $cycle) is supported until $eol"
    else
      echo "❌ Version $latest (cycle $cycle) is not supported (EOL: $eol)"
    fi
    
  done < <(jq -r '.[] | "\(.cycle) \(.releaseDate) \(.eol) \(.latest) \(.latestReleaseDate)"' "$versions_file")
  
  # Sort versions
  IFS=$'\n' sorted_versions=($(sort -V <<<"${supported_versions[*]}"))
  unset IFS
  
  echo "📊 Supported versions: ${sorted_versions[@]}"
  echo "${sorted_versions[@]}" > "${WORKSPACE_DIR}/${OUTPUT_DIR}/supported_versions.txt"
}

# Function to download OpenWRT overview for a specific version
download_overview() {
  local version=$1
  local output_dir="${WORKSPACE_DIR}/${OUTPUT_DIR}/${version}"
  local output_file="${output_dir}/overview.json"
  
  # Create directory
  mkdir -p "$output_dir"
  
  # Skip if file exists and we're not forcing download
  if [ -f "$output_file" ] && [ -s "$output_file" ] && [ "$FORCE_DOWNLOAD" != "true" ]; then
    echo "✅ Using existing overview for OpenWRT $version"
    return 0
  fi
  
  # URL for the overview file
  local url="https://downloads.openwrt.org/releases/${version}/.overview.json"
  
  if download_with_retries "$url" "$output_file" "OpenWRT $version overview"; then
    # Analyze overview to see how many targets are available
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
      local target_count=$(jq '.profiles | map(.target) | unique | length' "$output_file")
      local profile_count=$(jq '.profiles | length' "$output_file")
      echo "📊 OpenWRT $version has $profile_count device profiles across $target_count unique targets"
      return 0
    fi
  fi
  
  return 1
}

# Function to download a specific platform/target
download_platform() {
  local platform=$1
  local target=$2
  local version=$3
  
  # Create directory structure
  local target_dir="${WORKSPACE_DIR}/${OUTPUT_DIR}/${version}/${platform}/${target}"
  local output_file="${target_dir}/profiles.json"
  
  # Check if the file already exists and is valid
  if [ -f "$output_file" ] && [ -s "$output_file" ] && [ "$FORCE_DOWNLOAD" != "true" ]; then
    # Validate existing file
    if grep -q "\"profiles\":" "$output_file" 2>/dev/null; then
      local profile_count=$(grep -o "\"titles\":" "$output_file" | wc -l)
      echo "✅ Using existing profiles for ${platform}/${target} - ${profile_count} device profiles"
      return 0
    else
      echo "⚠️ Existing profile file for ${platform}/${target} appears invalid. Will download again."
    fi
  fi
  
  # Create directory if it doesn't exist
  mkdir -p "$target_dir"
  
  # Create URL and output filename
  local url="https://downloads.openwrt.org/releases/${version}/targets/${platform}/${target}/profiles.json"
  
  # Download with retries
  if download_with_retries "$url" "$output_file" "${platform}/${target} profiles for OpenWRT $version"; then
    # Count the number of profiles
    local profile_count=$(grep -o "\"titles\":" "$output_file" | wc -l)
    echo "✅ Downloaded ${platform}/${target} - ${profile_count} device profiles"
    return 0
  else
    # Don't remove the directory if it already existed with files
    if [ ! -f "$output_file" ]; then
      rm -rf "$target_dir"
    fi
    return 1
  fi
}

# Function to generate id-to-name mapping for a profile
generate_device_mapping() {
  local profile_file=$1
  local output_file="${profile_file%.json}-mapping.txt"
  
  # Skip if mapping file already exists and is non-empty
  if [ -f "$output_file" ] && [ -s "$output_file" ] && [ "$FORCE_DOWNLOAD" != "true" ]; then
    echo "✅ Using existing mapping file: $(basename "$output_file")"
    return 0
  fi
  
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
  
  echo "✅ Generated mapping file: $(basename "$output_file")"
}

# Create device search file for specific version
create_device_search() {
  local version=$1
  local base_dir="${WORKSPACE_DIR}/${OUTPUT_DIR}/${version}"
  local summary_file="${base_dir}/device-search.txt"
  
  # Skip if file exists and we're not forcing
  if [ -f "$summary_file" ] && [ -s "$summary_file" ] && [ "$FORCE_DOWNLOAD" != "true" ]; then
    echo "✅ Using existing device search file for OpenWRT $version"
    return 0
  fi
  
  echo "📝 Creating device search helper for OpenWRT $version..."
  
  echo "# OpenWrt Device Search Helper" > "$summary_file"
  echo "# Version: $version" >> "$summary_file"
  echo "# Generated: $(date)" >> "$summary_file"
  echo "# Format: device_id | platform/target | vendor | model" >> "$summary_file"
  echo "" >> "$summary_file"

  # Find all profile files for this version
  find "$base_dir" -name "profiles.json" | while read profile; do
    platform_path=${profile#$base_dir/}
    platform_path=${platform_path%/profiles.json}
    
    jq -r '.profiles | keys[]' "$profile" 2>/dev/null | while read id; do
      vendor=$(jq -r --arg id "$id" '.profiles[$id].titles[0].vendor // "Unknown"' "$profile")
      model=$(jq -r --arg id "$id" '.profiles[$id].titles[0].model // "Unknown"' "$profile")
      echo "$id | $platform_path | $vendor | $model" >> "$summary_file"
    done
  done
  
  local device_count=$(grep -v "^#" "$summary_file" | grep -v "^$" | wc -l)
  echo "✅ Created device search helper with $device_count devices: $(basename "$summary_file")"
}

# Main execution starts here
echo "🚀 Starting OpenWRT profile management..."

# Get OpenWRT versions from endoflife.date API
get_openwrt_versions

# Find supported versions
find_supported_versions

# Determine which version to use
if [ -z "$VERSION" ] || [ "$VERSION" == "latest" ]; then
  VERSION=$(head -n1 "${WORKSPACE_DIR}/${OUTPUT_DIR}/supported_versions.txt")
  echo "🔄 Using latest supported version: $VERSION"
fi

# Download the overview for the specified version
download_overview "$VERSION"

# Initialize counters
SUCCESS_COUNT=0
FAILURE_COUNT=0
SKIPPED_COUNT=0

# If specific platform provided, only download that one
if [ -n "$SPECIFIC_PLATFORM" ]; then
  # Split into platform and target
  PLATFORM=$(echo $SPECIFIC_PLATFORM | cut -d'/' -f1)
  TARGET=$(echo $SPECIFIC_PLATFORM | cut -d'/' -f2)
  
  if download_platform "$PLATFORM" "$TARGET" "$VERSION"; then
    SUCCESS_COUNT=$((SUCCESS_COUNT+1))
    generate_device_mapping "${WORKSPACE_DIR}/${OUTPUT_DIR}/${VERSION}/${PLATFORM}/${TARGET}/profiles.json"
  else
    FAILURE_COUNT=$((FAILURE_COUNT+1))
  fi
else
  # Download all common platforms
  for PLATFORM_TARGET in "${COMMON_PLATFORMS[@]}"; do
    # Split into platform and target
    PLATFORM=$(echo $PLATFORM_TARGET | cut -d'/' -f1)
    TARGET=$(echo $PLATFORM_TARGET | cut -d'/' -f2)
    
    # Check if profiles.json already exists for this platform/target
    TARGET_FILE="${WORKSPACE_DIR}/${OUTPUT_DIR}/${VERSION}/${PLATFORM}/${TARGET}/profiles.json"
    if [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ] && [ "$FORCE_DOWNLOAD" != "true" ]; then
      echo "⏩ Skipping download for ${PLATFORM}/${TARGET} - profiles already exist"
      SKIPPED_COUNT=$((SKIPPED_COUNT+1))
      # Still generate mapping file if needed
      generate_device_mapping "$TARGET_FILE"
    elif download_platform "$PLATFORM" "$TARGET" "$VERSION"; then
      SUCCESS_COUNT=$((SUCCESS_COUNT+1))
      generate_device_mapping "${WORKSPACE_DIR}/${OUTPUT_DIR}/${VERSION}/${PLATFORM}/${TARGET}/profiles.json"
    else
      FAILURE_COUNT=$((FAILURE_COUNT+1))
    fi
  done
fi

# Create device search helper file
create_device_search "$VERSION"

echo ""
echo "📊 Summary for OpenWRT $VERSION:"
echo "  • Successful downloads: $SUCCESS_COUNT"
echo "  • Skipped (already exist): $SKIPPED_COUNT"
echo "  • Failed downloads: $FAILURE_COUNT"

PROFILE_COUNT=$(find "${WORKSPACE_DIR}/${OUTPUT_DIR}/${VERSION}" -name "profiles.json" | wc -l)
if [ "$PROFILE_COUNT" -eq 0 ]; then
  echo "❌ ERROR: No profiles were found or downloaded for OpenWRT $VERSION!"
  exit 1
fi

echo ""
echo "📋 Device count by platform for OpenWRT $VERSION:"
find "${WORKSPACE_DIR}/${OUTPUT_DIR}/${VERSION}" -name "profiles.json" | while read profile; do
  count=$(jq '.profiles | length' "$profile" 2>/dev/null || echo "?")
  platform_path=${profile#${WORKSPACE_DIR}/${OUTPUT_DIR}/${VERSION}/}
  platform_path=${platform_path%/profiles.json}
  printf "%-25s %3s devices\n" "$platform_path" "$count"
done

echo ""
echo "✨ Done! Profiles are available at: ${WORKSPACE_DIR}/${OUTPUT_DIR}/${VERSION}"
echo ""
echo "🔎 To find a device ID for a specific model, use:"
echo "   grep -i \"your-model-name\" \"${WORKSPACE_DIR}/${OUTPUT_DIR}/${VERSION}/device-search.txt\""

# For GitHub Actions - set output variables
if [ -n "$GITHUB_OUTPUT" ]; then
  echo "count=$PROFILE_COUNT" >> $GITHUB_OUTPUT
  echo "skipped=$SKIPPED_COUNT" >> $GITHUB_OUTPUT
  echo "downloaded=$SUCCESS_COUNT" >> $GITHUB_OUTPUT
  echo "version=$VERSION" >> $GITHUB_OUTPUT
fi