It’s not directly caused by having extra files in “files/” alongside installing the same executables as packages. In most cases, OpenWrt’s Image Builder just merges whatever is in “files/” into the final root filesystem, and that by itself doesn’t usually trigger a build failure.

Instead, the crucial part of the error is that the Image Builder tried to produce “openwrt-23.05.3-ath79-generic-glinet_gl-ar300m16-squashfs-sysupgrade.bin” but never actually created that file, leading to “No such file or directory” and “Failed to open firmware file.” The “Bad file descriptor” message is essentially a side effect of the script attempting to work with a file that does not exist.

Common reasons why that firmware file never gets produced include:

• The device profile name in your build script doesn’t match what the Image Builder expects.  
• The final image is too large for your device (for instance, the -ar300m vs. -ar300m16 or NOR/NAND variants might have different flash sizes).  
• A package conflict or broken dependency is causing the build to fail silently before the sysupgrade image is generated.

To fix this:

1. Double-check that the PROFILE you’re specifying really matches the available device profiles. For a GL-AR300M16 device, OpenWrt often uses “glinet_gl-ar300m-nor” or similar naming in its build system, so confirm that “glinet_gl-ar300m16” is valid for 23.05.3.  
2. Make sure you haven’t exceeded the flash size. If the combined image ends up larger than the device supports, the builder can fail without generating the sysupgrade file. Consider removing unneeded packages if the image is too big.  
3. Look closely at the build output earlier in the process (right before the error) for clues that the builder might have hit a package dependency error or ran out of space.

In other words, the leftover files in “files/” usually don’t cause the image build to fail outright. More likely, the builder never successfully created the final firmware image because the profile was invalid or the image was too large, resulting in the missing sysupgrade bin.  