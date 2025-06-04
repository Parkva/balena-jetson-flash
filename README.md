# jetson-flash

> This tool allows users to flash BalenaOS on Jetson supported devices

This tool is separate into two parts:
- Extract BalenaOS image from a BalenaOS flasher image (this will be moved to [etcher](https://github.com/balena-io/etcher) once the fatfs issues are fixed)
- Flash BalenaOS via USB on a Jetson board (this will be moved to [etcher](https://github.com/balena-io/etcher))

Balena devices support
---------------------

* Jetson Nano eMMC - L4T 32.7.1
* Jetson Nano SD-CARD Devkit - L4T 32.7.1
* Jetson Nano 2GB Devkit - L4T 32.7.1
* Jetson TX2 - L4T 32.6.1
* Jetson TX2 NX (in Jetson Xavier NX Devkit) - L4T 32.7.1
* Jetson Xavier AGX - L4T 32.7.1
* Jetson Xavier NX Devkit eMMC - L4T 32.7.6
* Jetson Xavier NX Devkit SD-CARD - L4T 32.7.6

WARNINGS
--------

Due to issues with the fatfs node module, which does not support some operations we cannot transfer the following Balena configurations:

* system-proxy

Assumptions
-----------

- Linux based host - we test this tool with Ubuntu
- Sudo privileges

Prerequisites
-------------

- A Jetson BalenaOS image.
- Please unzip the image downloaded from the dashboard before passing it to the flashing tool.

Tool dependencies
-----------------

- [NodeJS](https://nodejs.org) (v10 or v12. Currently versions newer than v12 are incompatible, see issue #48)
- This tool runs internally the Linux_for_Tegra package, so we assume you have all the dependencies for this tool installed.

Getting Started
---------------

NOTES:
 - Make sure that the Jetson board is pluged to your host via USB and is in recovery mode
 - Running the Tegra flash tool requires sudo priviliges
 - This tool will produce all intermidiate steps in `/tmp/${pid_of_process}` and will require sudo priviliges to delete
 - If flashing Jetson TX2 with a BalenaOS image older than 2.47, please checkout tag 'v0.3.0'. BalenaOS 2.47 updated L4T version from 28.3 to 32.4.2.
 - Current BSP version used for flashing each device type is mentioned in the "Balena devices support" section above. Devices that are listed for L4T 32.6.1 are currently in progress of having their images updated to 32.7.1 in balena-cloud. Please ensure the BalenaOS version you are flashing uses the same L4T, by consulting the changelog available in the [BalenaOS Jetson repository](https://github.com/balena-os/balena-jetson/commits/master). Jetson Flash v0.5.10 should be used for flashing devices on L4T 32.4.4.

Clone this repository
```sh
$ git clone https://github.com/balena-os/jetson-flash.git
```

Run the cli, specifying desired device type:
```sh
$ ./bin/cmd.js -f balena.img -m <device_type>
```

Current supported device types are: jetson-nano-emmc, jetson-nano-qspi-sd, jetson-tx2, jetson-xavier-nx-devkit-tx2-nx, jetson-xavier, jetson-xavier-nx-devkit-emmc, jetson-xavier-nx-devkit

Support
-------

If you're having any problems, please [raise an issue](https://github.com/balena-os/jetson-flash/issues/new) on GitHub and the balena.io team will be happy to help.

License
-------

The project is licensed under the Apache 2.0 license.


Parkva Changes
--------------

We encountered issues when trying to flash an NVIDIA Xaviar NX device.

This is the error we get when attempting to flash using Jetpack 4.6 l4t 32.6.1

```jsx
0000000000000102: E> NONE: Invalid value MemBct dram size: 0MB for slot: 0.
```

### The exact same problem we are seeing

[Flashing Jetson Xavier NX 8GB fails - Invalid value MemBct dram size: 0MB for slot: 0](https://forums.developer.nvidia.com/t/flashing-jetson-xavier-nx-8gb-fails-invalid-value-membct-dram-size-0mb-for-slot-0/320795)

[Different Xavier NX Modules Exhibit Inconsistent Flashing Behavior](https://forums.developer.nvidia.com/t/different-xavier-nx-modules-exhibit-inconsistent-flashing-behavior/223801)


### Helpful Resources

[NVIDIA Jetson FAQ](https://developer.nvidia.com/embedded/faq#jetson-part-numbers)

[Jetson Linux R32.6.1 Release Page](https://developer.nvidia.com/embedded/linux-tegra-r3261)

#### This discusses the patch that is needed to support the 16GB eMMC

[How to use NVIDIA Jetson devices on balena - 2024 edition](https://blog.balena.io/how-to-use-nvidia-jetson-devices-on-balena/)

[Archived Documentation For Jetson Software](https://docs.nvidia.com/jetson/archives/)

[JetPack Archive](https://developer.nvidia.com/embedded/jetpack-archive)

### This JetPack version solves the DRAM problem

[JetPack SDK 4.6.6](https://developer.nvidia.com/jetpack-sdk-466)

This provides support for the new DRAM: Micron MT53E1G32D2FW-046 WT:B.

### Balena-based solution

In installer-01 device:

1. Download jetson-flash from https://github.com/balena-os/jetson-flash
2. Switch to tag v0.5.23 (determined this from: https://github.com/balena-os/jetson-flash/blob/master/docs/jetson-xavier-nx-devkit-emmc.md)
3. Install NodeJS version 12.22.12 and npm init to install dependencies
4. Modify resin-jetson-flash.js source to change the URL for “jetson-xavier-nx-devkit-emmc” to be “https://developer.nvidia.com/embedded/l4t/r32_release_v7.6/t186/jetson_linux_r32.7.6_aarch64.tbz2” to pick up the Nvidia Micron DRAM fixes.
5. In balena.io, add a new device for device type “Nvidia Jetson Xavier NX Devkit eMMC” with a Balena OS of “2.98.33” and download that to the ~/images directory
6. To flash:

```jsx
./bin/cmd.js -f ~/images/balena-cloud-patrol-prod-jetson-xavier-nx-devkit-emmc-2.98.33-v13.1.11.img  -m jetson-xavier-nx-devkit-emmc
```
