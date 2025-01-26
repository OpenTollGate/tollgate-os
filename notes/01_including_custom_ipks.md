You can copy your custom IPK files into the “packages” subdirectory of the extracted Image Builder folder (for example, …/openwrt-imagebuilder-‹PLATFORM›-‹TYPE›.Linux-x86_64/packages). Then, inside that same directory, run the package index command so that the image builder can pick them up.

After that, when you run the make image command, include your package names in the PACKAGES variable (the same way you’re including the base and extra packages), and the image builder will automatically install them.  

For example:

```bash
# Inside your image builder directory
mkdir -p packages/local
cp /path/to/ipk/*.ipk packages/local/

# Generate package index so they are recognized
make package/index

# Now build your firmware with those packages included
make -j$(nproc) image PROFILE="..." PACKAGES="... your_custom_package ..." FILES="..."
```

As long as the IPK files are in the packages directory and indexed before building, they will be available for inclusion in the image.