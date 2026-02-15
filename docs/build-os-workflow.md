# TollGate OS Build Workflow

This document describes the flow of the `.github/workflows/build-os.yml` workflow, which builds and publishes TollGate OS firmware images.

## Overview

The workflow builds OpenWRT-based firmware images for multiple device types, fetches the `tollgate-wrt` package from Nostr, and publishes the resulting firmware back to Nostr with NIP-94 metadata.

## Triggers

- **Manual dispatch** (`workflow_dispatch`): Can be triggered manually with optional package overrides:
  - `override_tollgate_wrt_version`: Override the tollgate-wrt package version (optional)
  - `override_tollgate_wrt_author`: Override the tollgate-wrt package author pubkey (optional)
- **Push events**: Automatically runs on code pushes

## Package Configuration

The workflow uses `packages.json` in the repository root to define which packages should be included in the build. This file specifies:
- Package name (e.g., `tollgate-wrt`)
- Package author (Nostr pubkey in hex format)
- Package version

Example `packages.json`:
```json
{
  "packages": {
    "tollgate-wrt": {
      "author": "74fffd9c15ae65c42ec4e07dc274ca4221ad8b7046fefbd55f031ca945b7147a",
      "version": "v0.3.2"
    }
  }
}
```

The workflow reads this file during the build process and can override values via workflow inputs.

## Workflow Jobs

### 1. `define-matrix`

**Purpose**: Defines the build matrix for all supported devices.

**Steps**:
1. Creates a JSON matrix with device configurations:
   - `glinet_gl-mt3000`
   - `glinet_gl-mt6000`
   - `glinet_gl-ar300m16`
   - `glinet_gl-ar300m-nor`
2. Each device specifies its OpenWRT version (24.10.1)

**Outputs**:
- `matrix`: JSON array of device configurations

---

### 2. `determine-versioning`

**Purpose**: Determines version numbers and release channels for both the OS and the tollgate-wrt package.

**Steps**:

1. **Checkout code** with full history (for commit counting)

2. **Get commit hash**: Extracts short commit hash

3. **Determine OS version**:
   - **Tag builds**: Uses tag name (e.g., `v1.0.0`)
   - **Branch builds**: Uses format `[branch].[height].[hash]` (e.g., `main.42.abc123`)
   - Sanitizes branch names (replaces `/` with `-`)

4. **Determine release channel**:
   - `v1.2.3-alpha*` → `alpha`
   - `v1.2.3-beta*` → `beta`
   - `v1.2.3` → `stable`
   - Everything else → `dev`

5. **Read packages.json and determine package config**:
   - Reads `packages.json` from repository root
   - Extracts tollgate-wrt author and version
   - Applies override logic:
     - **Manual override**: Uses `override_tollgate_wrt_version` if provided
     - **Tag builds**: Uses same version as OS tag
     - **Default**: Uses version from `packages.json`
   - Author override:
     - **Manual override**: Uses `override_tollgate_wrt_author` if provided
     - **Default**: Uses author from `packages.json`

**Outputs**:
- `os_version`: TollGate OS version string
- `release_channel`: Release channel (alpha/beta/stable/dev)
- `tollgate_wrt_version`: Package version to fetch
- `tollgate_wrt_author`: Package author pubkey to filter by

---

### 3. `build-firmware`

**Purpose**: Builds firmware images for each device in the matrix.

**Dependencies**: `determine-versioning`, `define-matrix`

**Strategy**: Matrix build (one job per device, fail-fast disabled)

**Steps**:

1. **Checkout code** at specified ref

2. **Initialize**: Set firmware filename

3. **Get device architecture**:
   - Fetches device metadata from OpenWRT
   - Extracts target and architecture (e.g., `aarch64_cortex-a53`)

4. **Install nak**: Downloads nak CLI tool for Nostr operations

5. **Fetch tollgate-wrt package from Nostr**:
   - Searches Nostr relays for NIP-94 events (kind 1063)
   - Filters by:
     - Author pubkey (from packages.json or override)
     - Package name tag (`n=tollgate-wrt`)
     - Version tag (`v=<version>`)
     - Architecture tag (`A=<architecture>`)
   - Downloads package from Blossom URL
   - Verifies SHA256 hash

6. **Build firmware**:
   - Calls `actions/build-os` action
   - Passes custom packages path
   - Builds OpenWRT image with TollGate customizations

7. **Copy artifacts**:
   - Copies to `/tmp/tollgate-artifacts` (for act compatibility)
   - Copies to `./artifacts` (for GitHub Actions)

8. **Upload to GitHub** (if not running in act):
   - Uploads firmware as GitHub artifact
   - 5-day retention

---

### 4. `publish-metadata`

**Purpose**: Uploads firmware to Blossom and publishes NIP-94 metadata to Nostr.

**Dependencies**: `determine-versioning`, `build-firmware`, `define-matrix`

**Strategy**: Matrix publish (one job per device)

**Container**: Ubuntu with volume mount for act compatibility

**Steps**:

1. **Checkout code** at specified ref

2. **Initialize**: Set firmware filename

3. **Install tools**: curl, jq

4. **Get artifact**:
   - **act**: Copy from mounted volume
   - **GitHub**: Download from artifacts

5. **Get firmware details**: Extract file size

6. **Get device metadata**:
   - Fetches architecture from OpenWRT
   - Gets supported device list

7. **Install nak**: Downloads nak CLI tool

8. **Upload to Blossom**:
   - Uploads firmware file using nak
   - Gets Blossom URL and SHA256 hash

9. **Publish NIP-94 metadata**:
   - Creates kind 1063 event with tags:
     - `url`: Blossom download URL
     - `m`: MIME type (application/octet-stream)
     - `x`, `ox`: SHA256 hash
     - `size`: File size in bytes
     - `filename`: Firmware filename
     - `A`: Architecture
     - `device_id`, `d`: Device ID
     - `supported_devices`: Comma-separated list
     - `openwrt_version`: OpenWRT version
     - `v`: OS version
     - `c`: Release channel
     - `n`: Package name (tollgate-os)
   - Publishes to Nostr relays

10. **Verify publication**:
    - Checks if event exists on relays
    - Fails if not found on any relay

---

## Key Features

### Nostr Integration

- **Package Discovery**: Fetches tollgate-wrt packages from Nostr using NIP-94 metadata
- **Firmware Publishing**: Publishes built firmware to Nostr with comprehensive metadata
- **Decentralized Storage**: Uses Blossom for file storage

### Version Management

- **Automatic versioning**: Derives versions from git tags and commits
- **Release channels**: Supports alpha, beta, stable, and dev channels
- **Package coordination**: Matches OS and package versions for tagged releases

### Compatibility

- **GitHub Actions**: Full support for GitHub's CI/CD
- **nektos/act**: Compatible with local testing using act
- **Conditional logic**: Adapts behavior based on environment

### Build Matrix

- **Multi-device**: Builds for 4 different device types in parallel
- **Fail-safe**: Continues building other devices if one fails
- **Architecture-aware**: Fetches correct package variant for each device

---

## Environment Variables

- `DEBUG`: Set to "true" for verbose output
- `FIRMWARE_FILENAME`: Generated firmware filename
- `DEVICE_ARCHITECTURE`: Device CPU architecture
- `TOLLGATE_WRT_PACKAGE_PATH`: Path to downloaded package
- `FIRMWARE_PATH`: Path to built firmware
- `FIRMWARE_SIZE`: Firmware file size in bytes
- `OS_ARCHITECTURE`: OpenWRT architecture string
- `OS_SUPPORTED_DEVICES`: Comma-separated device list

---

## Secrets Required

- `NSEC`: Nostr secret key (hex format) for signing and uploading
- `NOSTR_SECRET_KEY`: Nostr secret key (alternative format)
- `NOSTR_PUBLIC_KEY`: Nostr public key
- `NSECBECH`: Nostr secret key (bech32 format)

---

## Workflow Diagram

```
┌─────────────────────┐
│  define-matrix      │
│  (Device configs)   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ determine-versioning│
│ - OS version        │
│ - Release channel   │
│ - Package version   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  build-firmware     │◄─── Matrix: 4 devices
│ 1. Get architecture │
│ 2. Fetch package    │◄─── Nostr (NIP-94)
│ 3. Build image      │
│ 4. Upload artifact  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ publish-metadata    │◄─── Matrix: 4 devices
│ 1. Get artifact     │
│ 2. Upload Blossom   │───► Blossom server
│ 3. Publish NIP-94   │───► Nostr relays
│ 4. Verify           │
└─────────────────────┘
```

---

## Example Usage

### Build from main branch
```bash
# Automatically triggered on push
git push origin main
```

### Build a specific tag
```bash
# Tag the release
git tag v1.0.0
git push origin v1.0.0

# Workflow automatically:
# - Uses v1.0.0 for OS version
# - Fetches tollgate-wrt v1.0.0 package (from author in packages.json)
# - Sets release_channel to "stable"
```

### Manual build with custom package version
```yaml
# In GitHub Actions UI:
# 1. Go to Actions → Build and Publish TollGate OS
# 2. Click "Run workflow"
# 3. Fill in (all optional):
#    - override_tollgate_wrt_version: v0.4.0
#    - override_tollgate_wrt_author: abc123...def456
#
# This will:
# - Use the specified version instead of packages.json version
# - Use the specified author instead of packages.json author
# - Fetch package from Nostr matching these criteria
```

---

## Output Artifacts

### GitHub Artifacts (temporary)
- Firmware images for each device
- 5-day retention
- Named: `tollgate-os-{device_id}-{version}.bin`

### Nostr/Blossom (permanent)
- Firmware files stored on Blossom
- NIP-94 metadata events on Nostr relays
- Searchable by version, device, architecture, channel

---

## Troubleshooting

### Package not found
- Ensure the tollgate-wrt package version exists on Nostr
- Check that the architecture matches the device
- Verify Nostr relays are accessible

### Build failures
- Check OpenWRT version compatibility
- Verify device_id exists in OpenWRT metadata
- Review build logs for compilation errors

### Upload failures
- Verify NSEC secret is correct (hex format)
- Check Blossom server availability
- Ensure file size is within limits