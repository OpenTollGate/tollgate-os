#!/bin/bash
# select_modules.sh - Tool to select which modules from release.json to include in build
#
# Usage:
#   ./select_modules.sh [--exclude module1,module2,...] [--include module3,module4,...]
#
# If no arguments are provided, all modules in release.json are included

set -e

# Default values
EXCLUDE_MODULES=""
INCLUDE_MODULES=""
RELEASE_JSON="files/etc/tollgate/release.json"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --exclude)
      EXCLUDE_MODULES="$2"
      shift 2
      ;;
    --include)
      INCLUDE_MODULES="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: ./select_modules.sh [--exclude module1,module2,...] [--include module3,module4,...]"
      exit 1
      ;;
  esac
done

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed."
  exit 1
fi

# Check if release.json exists
if [ ! -f "$RELEASE_JSON" ]; then
  echo "Error: $RELEASE_JSON not found."
  exit 1
fi

# Get all available modules from release.json
ALL_MODULES=$(jq -r '.modules[].name' "$RELEASE_JSON" | tr '\n' ' ')
echo "Available modules: $ALL_MODULES"

# If include is specified, use only those modules
if [ -n "$INCLUDE_MODULES" ]; then
  SELECTED_MODULES=$(echo "$INCLUDE_MODULES" | tr ',' ' ')
  echo "Including only these modules: $SELECTED_MODULES"
else
  # Start with all modules
  SELECTED_MODULES="$ALL_MODULES"
  
  # If exclude is specified, remove those modules
  if [ -n "$EXCLUDE_MODULES" ]; then
    for module in $(echo "$EXCLUDE_MODULES" | tr ',' ' '); do
      SELECTED_MODULES=$(echo "$SELECTED_MODULES" | sed "s/\b$module\b//g")
    done
    echo "Excluding modules: $EXCLUDE_MODULES"
  fi
fi

# Clean up extra spaces
SELECTED_MODULES=$(echo "$SELECTED_MODULES" | tr -s ' ' | sed 's/^ //g' | sed 's/ $//g')
echo "Final selected modules: $SELECTED_MODULES"

# Output the selected modules
echo "$SELECTED_MODULES"