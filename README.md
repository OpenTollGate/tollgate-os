# TollGate OS
![logo](TollGate_Logo-C-black.png)

Custom OpenWrt firmware images that ship with the TollGate package
(`tollgate-wrt`) preinstalled, published to Nostr for decentralised
distribution.

## What this repo does

The single workflow ([`.github/workflows/publish-os.yml`](.github/workflows/publish-os.yml))
runs on push, pull_request, manual dispatch, or a `repository_dispatch`
event from [tollgate-module-basic-go](https://github.com/OpenTollGate/tollgate-module-basic-go).
For each (device, OpenWrt version, package format, compression) cell
it:

1. Resolves the device's target + architecture from
   `downloads.openwrt.org/releases/<version>/.overview.json`.
2. Downloads the right OpenWrt **image builder** for that target
   (24.10.x default = `.tar.xz`; 25.12.x default = `.tar.zst`).
3. Fetches the matching `tollgate-wrt` package over Nostr (NIP-94
   kind 1063), filtered by `n=tollgate-wrt`, `v=<version>`,
   `A=<arch>`, then post-receive jq-filtered on `compression` and
   `format` (relays don't index multi-letter tags per NIP-01).
4. Verifies the SHA-256, drops the file into the imagebuilder's
   custom-package dir (different per format — see below).
5. Runs `make image PROFILE=<device> PACKAGES="..."`.
6. Uploads the resulting `*-sysupgrade.bin` to Blossom and publishes
   a NIP-94 event so the [release explorer](https://github.com/OpenTollGate/tollgate-release-explorer-site)
   can find it.

## Supported devices

| Device | Target | OpenWrt 24.10.x (.ipk) | OpenWrt 25.12.x (.apk) |
|---|---|:---:|:---:|
| GL.iNet GL-MT3000 | mediatek/filogic | ✓ | ✓ |
| GL.iNet GL-MT6000 | mediatek/filogic | ✓ | ✓ |
| ComFast CF-WR632AX | mediatek/filogic |  | ✓ |
| GL.iNet GL-AR300M16 | ath79/nand | ✓ |  |
| GL.iNet GL-AR300M-NOR | ath79/nand | ✓ |  |
| D-Link COVR-X1860-A1 | mediatek/filogic | ✓ |  |
| Ubiquiti UniFi AC-Pro | ath79/generic | ✓ |  |

25.x rows are limited to the cortex-a53 / mediatek-filogic family
because that's the only architecture
[basic-go](https://github.com/OpenTollGate/tollgate-module-basic-go)
currently publishes `.apk` packages for. Adding more 25.x archs is
a one-line change in the device matrix once basic-go publishes apks
for them.

## Package format: ipk vs apk

The build path forks on the `format` matrix entry:

- **ipk** (OpenWrt 24.x and older) — file goes to
  `<imagebuilder>/packages/local/`, indexed by
  `scripts/ipkg-make-index.sh`, installed via `opkg`.
- **apk** (OpenWrt 25.x and newer) — file is renamed to the
  canonical Alpine form `<name>-<version>.apk` (apk-tools v3
  resolves index entries by that exact name), dropped at the
  imagebuilder's top-level `packages/`, indexed automatically by
  `apk mkndx --output packages.adb` inside `make image`.

## Compression matrix

UPX variants (`upx-fast`, `upx-best`, `upx-brute`, `upx-ultra-brute`)
are expensive — each one builds a complete firmware image — so
they're gated to release contexts only:

- push to `main`
- tags matching `v*`
- `pull_request` events
- `repository_dispatch` (basic-go-fired; basic-go gates upstream)
- `workflow_dispatch` with `full_compression: true`

Other branch pushes get the `compression=none` cells only.

## Configuration

[`packages.json`](packages.json) defines the default
`tollgate-wrt` package the workflow installs:

```json
{
  "packages": {
    "tollgate-wrt": {
      "author": "5075e61f0b048148b60105c1dd72bbeae1957336ae5824087e52efa374f8416a",
      "version": "v0.3.2",
      "compression": "none"
    }
  }
}
```

The workflow filters Nostr events by:

- **author** pubkey (trusts only this signer)
- **package name** (`n=tollgate-wrt`)
- **version** (matches the value in `packages.json` or the
  `override_tollgate_wrt_version` workflow_dispatch input)
- **architecture** (per device target)
- **compression** + **format** (post-receive)

## Manual builds

```
gh workflow run publish-os.yml \
  --ref <branch> \
  -f override_tollgate_wrt_version=<branch.height.sha or vN.N.N> \
  [-f override_tollgate_wrt_author=<pubkey>] \
  [-f full_compression=true]
```

## Issues / Contributions

We use Nostr to manage issues and pull requests for this repository.

Requirements for contributing:
* Ability to push to this git remote, or
* Push to your own git remote with [ngit](https://gitworkshop.dev/) installed

Any remote branches beginning with `pr/` are rendered as open PRs from contributors on [GitWorkshop](https://gitworkshop.dev/npub1c03rad0r6q833vh57kyd3ndu2jry30nkr0wepqfpsm05vq7he25slryrnw/tollgate-image-builder/prs). Submit these by pushing a branch with the `pr/` prefix.

## License

GNU General Public License v3.0 — see the LICENSE file.
