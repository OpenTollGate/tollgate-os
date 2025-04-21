#!/usr/bin/env bash
set -euxo pipefail

VERSION=23.05.5
PROFILE=glinet_gl-mt3000
FILE=external_profiles/$VERSION/mediatek/filogic/profiles.json

# 1) Architecture
ARCH=$(jq -r '.arch_packages' "$FILE")

# 2) Default (base) packages
DEFAULT_PKGS=( $(jq -r '.default_packages[]' "$FILE") )

# 3) Platform / Type
TARGET=$(jq -r '.target' "$FILE")
PLATFORM=${TARGET%%/*}
TYPE=${TARGET#*/}

# 4) From the profiles block, pull the mt3000 entry:
#   a) Device‑specific packages
DEVICE_PKGS=( $(jq -r --arg p "$PROFILE" '.profiles[$p].device_packages[]' "$FILE") )

#   b) Image prefix
IMAGE_PREFIX=$(jq -r --arg p "$PROFILE" '.profiles[$p].image_prefix' "$FILE")

#   c) Sysupgrade & kernel image filenames
SYSUPGRADE_IMG=$(jq -r --arg p "$PROFILE" \
  '.profiles[$p].images[] | select(.type=="sysupgrade").name' "$FILE")
KERNEL_IMG=$(jq -r --arg p "$PROFILE" \
  '.profiles[$p].images[] | select(.type=="kernel").name' "$FILE")

#   d) Supported device strings
SUPPORTED=( $(jq -r --arg p "$PROFILE" '.profiles[$p].supported_devices[]' "$FILE") )

#   e) Human titles
VENDOR=$(jq -r --arg p "$PROFILE" '.profiles[$p].titles[0].vendor' "$FILE")
MODEL_TITLE=$(jq -r --arg p "$PROFILE" '.profiles[$p].titles[0].model' "$FILE")

# 5) Other metadata
VERSION_NUM=$(jq -r '.version_number' "$FILE")
SOURCE_EPOCH=$(jq -r '.source_date_epoch' "$FILE")

# Print them out
cat <<EOF
PLATFORM=$PLATFORM
TYPE=$TYPE
PROFILE=$PROFILE
ARCH=$ARCH
DEFAULT_PACKAGES=${DEFAULT_PKGS[*]}
DEVICE_PACKAGES=${DEVICE_PKGS[*]}
TOLLGATE_REMOVE="<your tollgate removals here>"
TOLLGATE_ADD="<your tollgate additions here>"
IMAGE_PREFIX=$IMAGE_PREFIX
SYSUPGRADE_IMAGE=$SYSUPGRADE_IMG
KERNEL_IMAGE=$KERNEL_IMG
SUPPORTED_DEVICES=${SUPPORTED[*]}
VENDOR=$VENDOR
MODEL_TITLE=$MODEL_TITLE
VERSION_NUMBER=$VERSION_NUM
SOURCE_DATE_EPOCH=$SOURCE_EPOCH
EOF
