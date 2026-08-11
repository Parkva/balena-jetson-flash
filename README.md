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

David note: Switch to tag v0.5.23 (determined this from: https://github.com/balena-os/jetson-flash/blob/master/docs/jetson-xavier-nx-devkit-emmc.md)

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

This assumes flashing a Balena Xavier NX device

In installer-01 device:

1. Download jetson-flash from https://github.com/balena-os/jetson-flash
2. Switch to the parkva branch
3. Install NodeJS version 12.22.12 and npm init to install dependencies

   > **Important:** This tool only works on Node v12 (versions newer than v12 are
   > incompatible — see issue #48). installer-01 defaults to a newer Node, so the
   > native `ext2fs` module will throw a `NODE_MODULE_VERSION` mismatch error unless
   > you switch to Node 12 first. A `.nvmrc` is included, so from the repo directory
   > just run `nvm use` before flashing (installs v12.22.12 with `nvm install`
   > if you don't have it yet):
   >
   > ```sh
   > cd ~/balena-jetson-flash   # or wherever you cloned it
   > nvm use                    # reads .nvmrc -> Node v12.22.12
   > ```
   >
   > You must run `nvm use` in every new terminal session, since the shell default
   > stays on the newer Node.

4. To flash:

```jsx
nvm use   # ensure Node v12 is active (see note above)
./bin/cmd.js -f /images/balena-cloud-patrol-prod-jetson-xavier-nx-devkit-emmc-2.98.33-v13.1.11.img  -m jetson-xavier-nx-devkit-emmc
```

   > **Tip:** About a minute in, the tool runs `flash.sh` under `sudo` and will
   > prompt for your password mid-flash. To get the prompt out of the way up front,
   > prime sudo's credential cache first (same terminal), so the later `sudo` call
   > reuses it silently:
   >
   > ```sh
   > sudo -v && ./bin/cmd.js -f /images/balena-cloud-patrol-prod-jetson-xavier-nx-devkit-emmc-2.98.33-v13.1.11.img -m jetson-xavier-nx-devkit-emmc
   > ```
   >
   > The cache lasts ~15 min by default; for a longer flash, re-run `sudo -v` shortly
   > beforehand.

## Parkva Patrol System and Application Setup

### Background information on Balena OS
https://docs.balena.io/learn/welcome/primer/

```sh
npm install
```

```sh
git clone  --single-branch --branch parkva git@github.com:Parkva/balena-jetson-flash.git
```

```sh
lsusb
```

```sh
./bin/cmd.js -f /images/balena-cloud-patrol-prod-jetson-xavier-nx-devkit-emmc-2.98.33-v13.1.11.img  -m jetson-xavier-nx-devkit-emmc
```

### Post-Flash Provisioning

Once a device has been flashed and comes online in balenaCloud, the remaining
configuration (rename, host OS `/etc/hosts` entry, the four NetworkManager connection
files, and the `MASKCAM_*` device variables) can be applied automatically instead of
by hand.

`scripts/provision-device.sh` drives the [balena CLI](https://github.com/balena-io/balena-cli)
to do all of it from a device UUID and device number.

#### One-time setup: install and log in to the balena CLI

The standalone CLI is self-contained (it bundles its own Node), so it avoids the
Node-12-vs-newer issue the flasher has — no `nvm use` needed for the CLI.

```sh
# Download the standalone Linux x64 release (-L follows GitHub's redirect)
curl -L -o balena-cli.tar.gz \
  https://github.com/balena-io/balena-cli/releases/download/v25.2.0/balena-cli-v25.2.0-linux-x64-standalone.tar.gz

# Extract — creates a ./balena/ folder with the launcher at balena/bin/balena
tar -xzf balena-cli.tar.gz

# Install system-wide so `balena` is on your PATH
sudo mv balena /usr/local/lib/balena-cli
sudo ln -s /usr/local/lib/balena-cli/bin/balena /usr/local/bin/balena

# Verify, then log in (web authorization opens a browser; use a token if headless)
balena version
balena login
balena whoami
```

#### Run the provisioning script

```sh
./scripts/provision-device.sh <device-uuid> <number>
```

What it does:

1. **Renames** the device to `zzz-p400<number>-xnx-eth0`.
2. **Host OS** (over `balena device ssh`): remounts `/` read-write, adds
   `10.42.0.1  parkvapatrol.com` to `/etc/hosts`, and writes the `cdc-wdm0`
   (cellular), `eth0` (shared-ethernet), `enP5p4s0` (poe-0), and `enP5p5s0` (poe-1)
   connection files under `/etc/NetworkManager/system-connections/` at `0600`. All of
   this is idempotent — re-running does not duplicate entries.
3. **Device variables**: sets the five `MASKCAM_*` variables for the `lpr-scan`
   service (`MASKCAM_CLIENT_ID`, `MASKCAM_PERMIT_SYSTEM`, `MASKCAM_TOWER_SYSTEM`,
   `MASKCAM_DEVICE_PASSWORD`, `MASKCAM_PROCESSOR_TYPE`).
4. **Shuts down** the device — the new config loads on next boot, so you can unplug
   it and move on to the next one.

Preview everything without touching the device with `--dry-run`:

```sh
./scripts/provision-device.sh <device-uuid> <number> --dry-run
```

Notes:

- The device must be **online** in balenaCloud (host OS SSH and shutdown require it).
- The values applied (name prefix/suffix, hosts entry, PoE static IPs, and
  `MASKCAM_*` values) live in a config block at the top of the script — edit there if
  they change.