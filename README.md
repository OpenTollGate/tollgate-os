# Build Tollgate Device Firmware

This script uses OpenWRT's image-builder to create a base firmware for supported devices without needing to recompile all packages.

## Struggling to get started?

* This [write-up](https://njump.me/nevent1qqsrkfkdwy8q693vtrs789t7gf0vt86avkp7ufcmn5j0rhuvpr35zsqprfmhxue69uhhgmmvd33x7mm5dqh8xar9deejuer9wchsyg9nugltwgmmxedv4xwf628swz33f4s6sdl8h58uhv8s89xae7mzrqpsgqqqqqqsy3ukmv) provides a general overview of targeting OpenWRT
* This [write-up](https://njump.me/nevent1qqs2yfg6yuzkfd8ymry2hqt9a8vzf86zsuwh4phkmumdfk5kpke95jsppemhxue69uhkummn9ekx7mp0qgst8c37ku3hkdj6e2vun550qu9rzntp4qm700g0ewc0qw2dmnakyxqrqsqqqqqpxv8pu3) provides details on building with the SDK
* And this [write-up](https://njump.me/nevent1qqsge5zzeya9e0v5pftg2durq5htc6cpd93d3qs7tezcfadsme0ckcqppemhxue69uhkummn9ekx7mp0qgst8c37ku3hkdj6e2vun550qu9rzntp4qm700g0ewc0qw2dmnakyxqrqsqqqqqppkccyz) provides details on generating images with the image builder

### Prepare dependencies before build
```
pip3 install nostr
```

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

### To test TollGate modules

#### Crows Nest
```
root@OpenWrt:~# tollgate-crowsnest 
2024/03/22 22:22:20 Starting Tollgate - CrowsNest
2024/03/22 22:22:20 v0.1.0|c1f4c025e746fd307203ac3d1a1886e343bea76ceec5e286c96fb353be6cadea|KiB|1049000|sat|192.168.1.1
2024/03/22 22:22:20 add element to inteface default_radio0, element: dd6b323132313231303176302e312e307c633166346330323565373436666433303732303361633364316131383836653334336265613736636565633565323836633936666233353362653663616465617c4b69427c313034393030307c7361747c3139322e3136382e312e31
2024/03/22 22:22:20 add element to inteface default_radio1, element: dd6b323132313231303176302e312e307c633166346330323565373436666433303732303361633364316131383836653334336265613736636565633565323836633936666233353362653663616465617c4b69427c313034393030307c7361747c3139322e3136382e312e31
2024/03/22 22:22:20 reloading wifi
2024/03/22 22:22:20 wifi reloaded
2024/03/22 22:22:20 Shutting down Tollgate - CrowsNest
```

#### Merchant
```
root@OpenWrt:~# tollgate-merchant 
Starting Tollgate - merchant
privateKey: f4be433e9648024b8d3ce6ab4798f0b8bfd87c3344a633a72af0fbdc6c352ac5 / nsec17jlyx05kfqpyhrfuu6450x8shzlaslpngjnr8fe27raacmp49tzsvfaz9v
pk: c1f4c025e746fd307203ac3d1a1886e343bea76ceec5e286c96fb353be6cadea / npub1c86vqf08gm7nqusr4s735xyxudpmafmvamz79pkfd7e480nv4h4qkynusp
```

#### Relay
```
root@OpenWrt:~# tollgate-relay 
Nostr Relay running on :3334
```

#### Valve
```
root@OpenWrt:~# tollgate-valve 
Starting Tollgate - Valve
sk: 63cb6bae765e3894c4a72dc1a67bc02355d5f8ef7ae82c93c431e0b9c0dee268
pk: 72cb5f103deba52c708833e631157f86b3f71af50acec807328a36387835891e
nsec1v09khtnktcuff3989hq6v77qyd2at7800t5zey7yx8stnsx7uf5q9hy8du
npub1wt947ypaawjjcuygx0nrz9tls6elwxh4pt8vspej3gmrs7p43y0qpzvjmh
```

#### Whoami
```
root@OpenWrt:~# tollgate-whoami 
Starting Tollgate - Whoami
Listening on port :2122
2024/03/22 22:23:01 listen tcp :2122: bind: address already in use
```

#### Services
The services are launched in `/etc/init.d`

```
root@OpenWrt:~# ps | grep "tollgate"
 4852 root     1203m S    tollgate-merchant
 4880 root     1203m S    tollgate-relay
 4974 root     1203m S    tollgate-valve
 5019 root     1201m S    tollgate-whoami
```

