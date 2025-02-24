# Tollgate Device Firmware Build Action

A GitHub Action that uses OpenWRT's image-builder to create base firmware for supported devices without needing to recompile all packages.

## Usage

```yaml
- name: Build Tollgate Firmware
  uses: your-organization/tollgate-image-builder@main
  with:
    model: 'gl-mt3000'
    publish_metadata: true
    relays: 'wss://relay.damus.io,wss://nos.lol'
    nsec: ${{ secrets.NSEC }}
```

### Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `model` | Device model to build firmware for (gl-ar300m, gl-mt3000, gl-mt6000) | Yes | - |
| `nostr_secret_key` | Nostr secret key for signing | No | - |
| `nostr_public_key` | Nostr public key for identification | No | - |
| `nostr_relays` | Comma-separated list of Nostr relays | No | wss://relay.damus.io,wss://nos.lol,wss://nostr.mom |

### Outputs

| Output | Description |
|--------|-------------|
| `firmware_path` | Path to the built firmware file |
| `firmware_name` | Name of the generated firmware file |

### Supported Models

Currently supported device models:
- gl-ar300m
- gl-mt3000
- gl-mt6000

### Installation on Device

```bash
# Copy firmware to device
scp /tmp/openwrt-build/openwrt-imagebuilder-23.05.3-mediatek-filogic.Linux-x86_64/bin/targets/mediatek/filogic/openwrt-23.05.3-mediatek-filogic-glinet_gl-mt3000-squashfs-sysupgrade.bin root@192.168.8.1:/tmp/.

# SSH to device and upgrade
ssh <device>
sysupgrade -v /tmp/firmware-file
```

## Issues / Contributions

We use Nostr to manage issues and pull requests for this repository.

Requirements for contributing:
* Ability to push to this git remote, or
* Push to your own git remote with [ngit](https://gitworkshop.dev/npub1c03rad0r6q833vh57kyd3ndu2jry30nkr0wepqfpsm05vq7he25slryrnw/tollgate-image-builder/prs) installed

Any remote branches beginning with `pr/` are rendered as open PRs from contributors on GitWorkshop. Submit these by pushing a branch with the `pr/` prefix.

## License

This project is licensed under the GNU General Public License v3.0 - see the LICENSE file for details.
