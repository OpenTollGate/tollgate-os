#!/bin/bash

# Script to create a unified router database from OpenWRT profiles
# This reduces redundancy by collecting all router information in one place
# Usage: ./create_router_db.sh [version] [output-dir]

# Process arguments
VERSION="${1:-23.05.5}"
OUTPUT_DIR="${2:-external_profiles}"
FORCE_REFRESH="${3:-false}"

# Set paths
WORKSPACE_DIR="${GITHUB_WORKSPACE:-$(pwd)}"
VERSION_DIR="${WORKSPACE_DIR}/${OUTPUT_DIR}/${VERSION}"
OVERVIEW_FILE="${VERSION_DIR}/.overview.json"
DB_FILE="${VERSION_DIR}/router-database.json"

echo "🔄 Creating unified router database for OpenWRT $VERSION..."

# Check if overview file exists
if [ ! -f "$OVERVIEW_FILE" ] || [ ! -s "$OVERVIEW_FILE" ]; then
  echo "❌ Overview file not found: $OVERVIEW_FILE"
  echo "   Run the fetch-overview action first"
  exit 1
fi

# Check if we should skip database creation if it already exists
if [ -f "$DB_FILE" ] && [ -s "$DB_FILE" ] && [ "$FORCE_REFRESH" != "true" ]; then
  echo "✅ Using existing router database for OpenWRT $VERSION"
  exit 0
fi

# Start creating database from overview data
echo "📊 Extracting basic router information from overview..."

# Extract key information from overview into new database format
jq '{
  version: "'$VERSION'",
  generated_at: "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'",
  routers: (.profiles | map({
    id: .id,
    target: .target,
    vendor: .titles[0].vendor,
    model: .titles[0].model,
    variant: .titles[0].variant,
    full_name: (
      if .titles[0].variant and .titles[0].variant != null then 
        .titles[0].vendor + " " + .titles[0].model + " (" + .titles[0].variant + ")" 
      else 
        .titles[0].vendor + " " + .titles[0].model 
      end
    ),
    has_full_profile: false,
    profile_path: (
      .target + "/profiles.json"
    )
  }))
}' "$OVERVIEW_FILE" > "$DB_FILE"

echo "✅ Created router database with $(jq '.routers | length' "$DB_FILE") routers"
echo "📂 Database file: $DB_FILE"

# This script could be extended to scan existing profile files and update the database with "has_full_profile" markers
# Find existing profile files and mark them in the database
for PROFILE_FILE in $(find "${VERSION_DIR}" -name "profiles.json"); do
  # Extract platform/target from path
  REL_PATH=${PROFILE_FILE#${VERSION_DIR}/}
  # Extract just the platform/target part (remove /profiles.json)
  TARGET=${REL_PATH%/profiles.json}
  
  if [ -f "$PROFILE_FILE" ] && [ -s "$PROFILE_FILE" ]; then
    echo "🔍 Found profile for $TARGET, marking routers in database..."
    
    # Update database to mark routers with this target as having a profile available
    jq --arg target "$TARGET" '.routers = (.routers | map(
      if .target == $target then 
        . + {has_full_profile: true} 
      else 
        . 
      end
    ))' "$DB_FILE" > "${DB_FILE}.tmp" && mv "${DB_FILE}.tmp" "$DB_FILE"
  fi
done

# Create a CSV version for easier grepping
CSV_FILE="${VERSION_DIR}/routers.csv"
echo "# id,target,vendor,model,full_name,has_profile" > "$CSV_FILE"
jq -r '.routers[] | [.id, .target, .vendor, .model, .full_name, (.has_full_profile|tostring)] | @csv' "$DB_FILE" >> "$CSV_FILE"

echo "✅ Created CSV export of router database: $CSV_FILE"
echo "✨ Done! Router database creation complete"