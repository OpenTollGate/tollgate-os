# Build Tollgate Device Firmware

This script uses OpenWRT's image-builder to create a base firmware for supported devices without needing to recompile all packages. 


### To build

```bash
# build-firmware <model>
# for example
./build-firmware gl-mt3000
```


### Installing
```bash
# scp -O /tmp/openwrt-build/openwrt-imagebuilder-23.05.3-<platform>-<type>.Linux-x86_64/bin/targets/<platform>/<type>/openwrt-23.05.3-<target-device>-<profile>-squashfs-sysupgrade.bin root@<dest>:/tmp
scp /tmp/openwrt-build/openwrt-imagebuilder-23.05.3-mediatek-filogic.Linux-x86_64/bin/targets/mediatek/filogic/openwrt-23.05.3-mediatek-filogic-glinet_gl-mt3000-squashfs-sysupgrade.bin root@192.168.8.1:/tmp/.

ssh <device>
sysupgrade -v /tmp/firmware-file
```

### Cross compile binaries
Next steps would be to cross-compile any binaries outside of the OpenWRT ecosystem and have them pulled into the base image build process.

```bash
sudo docker build -t openwrt-tester .

sudo docker run -it --rm --privileged -v /tmp/openwrt-build/openwrt-imagebuilder-ath79-nand.Linux-x86_64/bin/targets/ath79/nand/openwrt-ath79-nand-glinet_gl-e750-squashfs-sysupgrade.bin:/var/lib/qemu/firmware.bin openwrt-tester gl-e750 /var/lib/qemu/firmware.bin

```