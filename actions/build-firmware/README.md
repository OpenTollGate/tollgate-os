# TollGate OS Firmware Builder

This GitHub Action builds customized OpenWrt firmware images with TollGate packages included.

## How It Works

The action follows the OpenWrt build process as described in the official OpenWrt documentation:

1. **Device Profile Selection**: Finds the appropriate device profile based on the model name
2. **ImageBuilder Download**: Downloads the correct ImageBuilder for the platform
3. **Package Integration**: Adds TollGate-specific packages to the build
4. **Firmware Building**: Creates sysupgrade-compatible firmware images

## OpenWrt Naming Conventions

This action follows the official OpenWrt naming conventions:

### Profile Names
- Device profiles use underscore format: `manufacturer_model`, e.g., `glinet_gl-ar300m-nand`
- The action properly handles both generic and NAND-specific profiles

### ImageBuilder Naming
- Standard format: `openwrt-imagebuilder-[version]-[platform]-[subtype].Linux-x86_64`
- Special cases like ath79/nand: `openwrt-imagebuilder-[version]-ath79-nand.Linux-x86_64`

### Firmware Image Naming
- Output images follow the OpenWrt convention: `openwrt-[version]-[platform]-[subtype]-[device]-[variant]-sysupgrade.bin`

## Usage

```yaml
- name: Build firmware
  uses: OpenTollGate/tollgate-os/actions/build-firmware@main
  with:
    model: 'glinet_gl-mt300n-v2'
    version: '23.05.5'
    nostr_secret_key: ${{ secrets.NOSTR_SECRET_KEY }}
    nostr_public_key: ${{ secrets.NOSTR_PUBLIC_KEY }}
    nsecbech: ${{ secrets.NSECBECH }}
    nsec: ${{ secrets.NSEC }}
    base_packages: 'luci-app-ddns luci-app-upnp'
```

## Compatible Device Types

The action supports all device types that OpenWrt supports, including:

- **Standard/generic devices** (NOR flash-based)
- **NAND flash devices** (like ath79/nand)
- **MediaTek/Ralink** devices (ramips/mt7621)
- **Raspberry Pi** and other ARM-based devices
- **x86/x86_64** systems

When building for special types like NAND devices, the action automatically handles the correct ImageBuilder naming and build options.

## Custom Files

To include custom configuration in the firmware:

1. Create a directory with your custom files following OpenWrt's directory structure
2. Pass the path to that directory using the `files_path` input

The files will be included in the firmware image at build time.