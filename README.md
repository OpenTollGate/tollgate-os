# TollGate OS
![logo](TollGate_Logo-C-black.png)

TollGate OS is a custom OpenWRT-based firmware distribution that integrates with the Nostr protocol for decentralized package management and distribution.

## Overview

This repository builds and publishes TollGate OS firmware images for multiple device types. The build system:

- **Fetches packages from Nostr**: Uses NIP-94 metadata events to discover and download packages (like `tollgate-wrt`) from decentralized Nostr relays
- **Builds custom firmware**: Uses OpenWRT's image-builder to create firmware images without recompiling all packages
- **Publishes to Nostr**: Uploads built firmware to Blossom storage and publishes metadata back to Nostr for decentralized distribution
- **Version management**: Uses [`packages.json`](packages.json) to define which package versions to include in builds

## Supported Devices

- GL.iNet GL-MT3000
- GL.iNet GL-MT6000
- GL.iNet GL-AR300M16
- GL.iNet GL-AR300M-NOR

## Package Configuration

The [`packages.json`](packages.json) file defines which packages are included in the build:

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

The build workflow fetches packages from Nostr by filtering for:
- Author pubkey (ensures packages come from trusted sources)
- Package name and version
- Device architecture

## Workflow

See [`docs/build-os-workflow.md`](docs/build-os-workflow.md) for detailed documentation on the build and publish workflow.

## Issues / Contributions

We use Nostr to manage issues and pull requests for this repository.

Requirements for contributing:
* Ability to push to this git remote, or
* Push to your own git remote with [ngit](https://gitworkshop.dev/) installed

Any remote branches beginning with `pr/` are rendered as open PRs from contributors on [GitWorkshop]](https://gitworkshop.dev/npub1c03rad0r6q833vh57kyd3ndu2jry30nkr0wepqfpsm05vq7he25slryrnw/tollgate-image-builder/prs). Submit these by pushing a branch with the `pr/` prefix.

## License

This project is licensed under the GNU General Public License v3.0 - see the LICENSE file for details.
