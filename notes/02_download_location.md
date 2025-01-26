You should put the `packages/local` directory in the Image Builder directory, which in your case is under `/tmp/openwrt-build/openwrt-imagebuilder-23.05.3-ath79-generic.Linux-x86_64/` (for the ath79 platform) or `/tmp/openwrt-build/openwrt-imagebuilder-23.05.3-mediatek-filogic.Linux-x86_64/` (for the mediatek platform).

This is because the Image Builder looks for packages in its own directory structure when building the firmware. The first directory (with the `build-firmware` script and `files`) is just for your build configuration and custom files that get copied into the final image.

So, you would do something like:

```bash
# For ath79 platform
sudo mkdir -p /tmp/openwrt-build/openwrt-imagebuilder-23.05.3-ath79-generic.Linux-x86_64/packages/local
sudo cp /path/to/your/*.ipk /tmp/openwrt-build/openwrt-imagebuilder-23.05.3-ath79-generic.Linux-x86_64/packages/local/
cd /tmp/openwrt-build/openwrt-imagebuilder-23.05.3-ath79-generic.Linux-x86_64/
sudo make package/index
```

You'll need to add these steps to your `build-firmware` script before the final make command that builds the image.