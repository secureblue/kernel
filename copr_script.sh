#!/bin/bash

# SPDX-FileCopyrightText: Copyright 2026 The Secureblue Authors
#
# SPDX-License-Identifier: MIT

set -euxo pipefail

build_dir="$(realpath ..)"
readonly build_dir

script_dir="$(pwd)"
readonly script_dir

git clone https://src.fedoraproject.org/rpms/kernel.git
cd kernel
git checkout f44

# https://docs.copr.fedorainfracloud.org/user_documentation.html#webhooks
secureblue_buildid_version=$(jq -r '.secureblue_buildid_version' "${build_dir}/hook_payload")
readonly secureblue_buildid_version

fedpkg sources

configs_to_enable=(
  # https://www.kernelconfig.io/CONFIG_PROC_PAGE_MONITOR
  # requires a value set since its parent gets disabled
  CONFIG_PROC_PAGE_MONITOR

  # https://www.kernelconfig.io/CONFIG_INIT_ON_ALLOC_DEFAULT_ON
  # Equivalent to defaulting init_on_alloc=1, already set by Fedora and our kargs
  CONFIG_INIT_ON_ALLOC_DEFAULT_ON

  # https://www.kernelconfig.io/CONFIG_INIT_ON_FREE_DEFAULT_ON
  # Equivalent to defaulting init_on_free=1, already set by our kargs
  CONFIG_INIT_ON_FREE_DEFAULT_ON

  # https://cateee.net/lkddb/web-lkddb/INTEL_IOMMU_DEFAULT_ON.html
  # Equivalent to intel_iommu=on, already set by our kargs
  CONFIG_INTEL_IOMMU_DEFAULT_ON

  # https://www.kernelconfig.io/CONFIG_IOMMU_DEFAULT_DMA_STRICT
  # Equivalent to defaulting iommu.passthrough=0 iommu.strict=1, already set by our kargs
  CONFIG_IOMMU_DEFAULT_DMA_STRICT

  # https://www.kernelconfig.io/CONFIG_ZERO_CALL_USED_REGS
  # Zero contents of caller-used registers before returning.
  # Reduces side channel attack vectors with negligible perf impact and a
  # slight increase in kernel image size (<1% on x86_64, 5% on aarch64)
  CONFIG_ZERO_CALL_USED_REGS

  # https://cateee.net/lkddb/web-lkddb/DEBUG_NOTIFIERS.html
  # Sanity checks on notifier call chains, slight perf hit
  # in exchange for reduced kernel panics/oopses and dangling pointers
  CONFIG_DEBUG_NOTIFIERS
)

configs_to_disable=(
  # https://www.kernelconfig.io/CONFIG_IOMMU_DEFAULT_DMA_LAZY
  # Disabling this to override Fedora's enabling of it. Needed for STRICT to take effect.
  CONFIG_IOMMU_DEFAULT_DMA_LAZY

  # https://www.kernelconfig.io/CONFIG_X86_VSYSCALL_EMULATION
  # vsyscall emulation. Equivalent to defaulting vsyscall=none, already set by our kargs
  CONFIG_X86_VSYSCALL_EMULATION

  # https://www.kernelconfig.io/CONFIG_INFINIBAND
  # https://en.wikipedia.org/wiki/InfiniBand
  # InfiniBand support
  CONFIG_INFINIBAND

  # https://www.kernelconfig.io/CONFIG_NETCONSOLE
  # Network console logging support
  CONFIG_NETCONSOLE

  # https://www.kernelconfig.io/CONFIG_6LOWPAN
  # https://en.wikipedia.org/wiki/6LoWPAN
  # IPv6 over Low-Power Wireless Personal Area Networks
  # It was created with the intention of applying the Internet Protocol (IP) even to the smallest devices,
  # [3] enabling low-power devices with limited processing capabilities to participate in the Internet of Things.[1]
  CONFIG_6LOWPAN

  # https://www.kernelconfig.io/CONFIG_IEEE802154
  # IEEE Std 802.15.4 Low-Rate Wireless Personal Area Networks support
  # IEEE Std 802.15.4 defines a low data rate, low power and low
  # complexity short range wireless personal area networks. It was
  # designed to organise networks of sensors, switches, etc automation
  # devices. Maximum allowed data rate is 250 kb/s and typical personal
  # operating space around 10m.
  CONFIG_IEEE802154

  # https://www.kernelconfig.io/CONFIG_AF_RXRPC
  # RxRPC session sockets
  CONFIG_AF_RXRPC
  # Required for disabling RxRPC session sockets
  CONFIG_AFS_FS

  # https://www.kernelconfig.io/CONFIG_XDP_SOCKETS_DIAG
  # XDP sockets: monitoring interface
  CONFIG_XDP_SOCKETS_DIAG

  # https://www.kernelconfig.io/CONFIG_VSOCKETS_DIAG
  # Virtual Sockets monitoring interface
  CONFIG_VSOCKETS_DIAG

  # https://www.kernelconfig.io/CONFIG_HSR
  # High-availability Seamless Redundancy (HSR & PRP)
  # https://en.wikipedia.org/wiki/High-availability_Seamless_Redundancy
  # HSR nodes have two ports and act as a bridge, which allows arranging
  # them into a ring or meshed structure without dedicated switches. This
  # is in contrast to the companion standard Parallel Redundancy Protocol (PRP),[1]
  # with which HSR shares the operating principle.
  CONFIG_HSR

  # https://www.kernelconfig.io/CONFIG_NET_DSA
  # Distributed Switch Architecture
  # https://docs.kernel.org/networking/dsa/dsa.html
  CONFIG_NET_DSA

  # https://cateee.net/lkddb/web-lkddb/LDISC_AUTOLOAD.html
  # Don't autoload line disciplines, already set by our sysctl
  CONFIG_LDISC_AUTOLOAD


  ############################################################
  ####### Features for mobile carriers / datacenters #########
  ############################################################
  # GPRS Tunneling Protocol
  # https://www.kernelconfig.io/CONFIG_GTP
  CONFIG_GTP

  # Packet Forwarding Control Protocol
  # https://cateee.net/lkddb/web-lkddb/PFCP.html
  CONFIG_PFCP

  # Automatic Multicast Tunneling
  # https://cateee.net/lkddb/web-lkddb/AMT.html
  CONFIG_AMT

  # https://cateee.net/lkddb/web-lkddb/AF_KCM.html
  # Kernel Connection Multiplexor
  # Has been the source of CVEs, appears to have little to no use outside of 
  # datacenter applications. 
  CONFIG_AF_KCM

  # https://www.kernelconfig.io/CONFIG_BAREUDP
  # Used for applications like https://en.wikipedia.org/wiki/Multiprotocol_Label_Switching
  CONFIG_BAREUDP

  # Identifier Locator Addressing
  # https://cateee.net/lkddb/web-lkddb/IPV6_ILA.html
  # Draft protocol that's in the kernel but not a standard
  CONFIG_IPV6_ILA

  # ATA over ethernet
  # Obsolete datacenter protocol
  # https://cateee.net/lkddb/web-lkddb/ATA_OVER_ETH.html
  CONFIG_ATA_OVER_ETH

  ############################################################
  ################# Kernel testing features ##################
  ############################################################
  # https://www.kernelconfig.io/CONFIG_X86_MCE_INJECT
  # Machine check injector support
  CONFIG_X86_MCE_INJECT

  # https://www.kernelconfig.io/CONFIG_HWPOISON_INJECT
  # HWPoison pages injector
  CONFIG_HWPOISON_INJECT

  # https://www.kernelconfig.io/CONFIG_PCIEAER_INJECT
  # This enables PCI Express Root Port Advanced Error Reporting
  # (AER) software error injector.
  CONFIG_PCIEAER_INJECT

  # https://cateee.net/lkddb/web-lkddb/ACPI_APEI_EINJ.html
  # APEI error injection for debugging
  CONFIG_ACPI_APEI_EINJ

  # https://www.kernelconfig.io/CONFIG_SCSI_DEBUG
  # SCSI debugging host and device simulator
  CONFIG_SCSI_DEBUG

  # https://www.kernelconfig.io/CONFIG_USB_SERIAL_DEBUG
  # USB Debugging Device
  CONFIG_USB_SERIAL_DEBUG

  # https://www.kernelconfig.io/CONFIG_RING_BUFFER_BENCHMARK
  # Ring buffer benchmark stress tester
  CONFIG_RING_BUFFER_BENCHMARK

  # https://www.kernelconfig.io/CONFIG_DRM_VKMS
  # Virtual KMS (EXPERIMENTAL)
  CONFIG_DRM_VKMS

  # https://www.kernelconfig.io/CONFIG_USB_DUMMY_HCD
  # Dummy HCD (DEVELOPMENT)
  CONFIG_USB_DUMMY_HCD

  # https://www.kernelconfig.io/CONFIG_MTD_NAND_NANDSIM
  # Support for NAND Flash Simulator
  CONFIG_MTD_NAND_NANDSIM

  # https://www.kernelconfig.io/CONFIG_MTD_MTDRAM
  # Test driver using RAM
  CONFIG_MTD_MTDRAM

  # https://www.kernelconfig.io/CONFIG_MEDIA_TEST_SUPPORT
  # Test drivers
  # "These drivers should not be used on production kernels"
  CONFIG_MEDIA_TEST_SUPPORT

  # https://cateee.net/lkddb/web-lkddb/CRYPTO_BENCHMARK.html
  # "For use by people developing cryptographic algorithms in the kernel. It should not be enabled in production kernels."
  CONFIG_CRYPTO_BENCHMARK

  # https://cateee.net/lkddb/web-lkddb/X86_AMD_PSTATE_UT.html
  # Selftest for AMD Processor P-State driver
  # "This kernel module is used for testing"
  CONFIG_X86_AMD_PSTATE_UT

  # https://www.kernelconfig.io/CONFIG_I2C_STUB
  # I2C/SMBus Test Stub
  # This module may be useful to developers of SMBus client drivers,
  # especially for certain kinds of sensor chips
  # "If you don't know what to do here, definitely say N."
  CONFIG_I2C_STUB

  # https://www.kernelconfig.io/CONFIG_I2C_SLAVE_EEPROM
  # I2C slave mode EEPROM simulator
  CONFIG_I2C_SLAVE_EEPROM

  # https://www.kernelconfig.io/CONFIG_GPIO_SIM
  # GPIO Simulator Module
  CONFIG_GPIO_SIM

  # https://cateee.net/lkddb/web-lkddb/GPIO_VIRTUSER.html
  # GPIO Virtual User Testing Module
  CONFIG_GPIO_VIRTUSER

  # vDPA device simulator
  # https://cateee.net/lkddb/web-lkddb/VDPA_SIM.html
  # https://cateee.net/lkddb/web-lkddb/VDPA_SIM_NET.html
  # https://cateee.net/lkddb/web-lkddb/VDPA_SIM_BLOCK.html
  CONFIG_VDPA_SIM
  CONFIG_VDPA_SIM_NET
  CONFIG_VDPA_SIM_BLOCK

  # NVMe over Fabrics FC Transport Loopback Test driver
  # https://cateee.net/lkddb/web-lkddb/NVME_TARGET_FCLOOP.html
  CONFIG_NVME_TARGET_FCLOOP

  # NTB (Non-Transparent Bridge) testing
  # https://cateee.net/lkddb/web-lkddb/NTB_PERF.html
  # https://cateee.net/lkddb/web-lkddb/NTB_PINGPONG.html
  # https://cateee.net/lkddb/web-lkddb/NTB_TOOL.html
  CONFIG_NTB_PERF
  CONFIG_NTB_PINGPONG
  CONFIG_NTB_TOOL

  # Block device testing
  # https://cateee.net/lkddb/web-lkddb/BLK_DEV_NULL_BLK.html
  # https://cateee.net/lkddb/web-lkddb/BLK_DEV_RUST_NULL.html
  # https://cateee.net/lkddb/web-lkddb/BLK_DEV_ZONED_LOOP.html
  CONFIG_BLK_DEV_NULL_BLK
  CONFIG_BLK_DEV_RUST_NULL
  CONFIG_BLK_DEV_ZONED_LOOP

  # Device mapper testing
  # https://cateee.net/lkddb/web-lkddb/DM_FLAKEY.html
  # https://cateee.net/lkddb/web-lkddb/DM_DUST.html
  # https://cateee.net/lkddb/web-lkddb/DM_DELAY.html
  # https://cateee.net/lkddb/web-lkddb/DM_LOG_WRITES.html
  CONFIG_DM_FLAKEY
  CONFIG_DM_DUST
  CONFIG_DM_DELAY
  CONFIG_DM_LOG_WRITES

  # Dummy soundcard driver
  # https://cateee.net/lkddb/web-lkddb/SND_DUMMY.html
  CONFIG_SND_DUMMY

  # Emulated bluetooth device
  # https://cateee.net/lkddb/web-lkddb/BT_HCIVHCI.html
  # Bluetooth Virtual HCI device driver. This driver is required if you want to use HCI Emulation software.
  CONFIG_BT_HCIVHCI

  # Allows ethernet drivers to be used as simulated Wifi connections
  # https://cateee.net/lkddb/web-lkddb/VIRT_WIFI.html
  CONFIG_VIRT_WIFI

  # Virtual graphics execution manager
  # https://cateee.net/lkddb/web-lkddb/DRM_VGEM.html
  CONFIG_DRM_VGEM

  # Support for Intel(R) Trace Hub (TH) and Coresight STM, hardware debugging tools
  # https://cateee.net/lkddb/web-lkddb/STM.html
  # https://cateee.net/lkddb/web-lkddb/INTEL_TH.html
  CONFIG_INTEL_TH
  CONFIG_CORESIGHT_STM
  CONFIG_STM

  # Virtual netlink monitoring device
  # https://cateee.net/lkddb/web-lkddb/NLMON.html
  # "This is mostly intended for developers or support to debug netlink issues."
  CONFIG_NLMON

  # Virtual vsock monitoring device
  # https://cateee.net/lkddb/web-lkddb/VSOCKMON.html
  # "It is mostly intended for developers or support to debug vsock issues."
  CONFIG_VSOCKMON

  # Driver for Synopsys DesignWare PCIe traffic generator, a PCIe testing device
  # https://cateee.net/lkddb/web-lkddb/DW_XDATA_PCIE.html
  CONFIG_DW_XDATA_PCIE

  # https://cateee.net/lkddb/web-lkddb/LATENCYTOP.html
  # https://en.wikipedia.org/wiki/LatencyTOP
  # Tool for debugging kernel latency
  CONFIG_LATENCYTOP

  # https://cateee.net/lkddb/web-lkddb/SUNRPC_DEBUG.html
  # Used for debugging NFS issues
  CONFIG_SUNRPC_DEBUG

  # https://cateee.net/lkddb/web-lkddb/XFS_ONLINE_SCRUB_STATS.html
  # xfs_scrub monitoring and data collection tooling
  CONFIG_XFS_ONLINE_SCRUB_STATS

  # https://cateee.net/lkddb/web-lkddb/PROVIDE_OHCI1394_DMA_INIT.html
  # Enables Firewire debugging over remote DMA
  CONFIG_PROVIDE_OHCI1394_DMA_INIT


  ############################################################
  ################# Unused ports and devices #################
  ############################################################
  # https://www.kernelconfig.io/CONFIG_SERIAL_NONSTANDARD
  # Non-standard serial port support
  # Say Y here if you have any non-standard serial boards -- boards
  # which aren't supported using the standard "dumb" serial driver.
  # This includes intelligent serial boards such as
  # Digiboards, etc. These are usually used for systems that need many
  # serial ports because they serve many terminals or dial-in
  # connections.
  CONFIG_SERIAL_NONSTANDARD

  # Load balancing when using internet over telephone lines
  # https://cateee.net/lkddb/web-lkddb/EQUALIZER.html
  CONFIG_EQUALIZER

  # SLIP (serial line) support
  # The obsolete way to access dial up. "Modern" dialup uses PPP.
  CONFIG_SLIP

  # Obsolete card support
  # https://en.wikipedia.org/wiki/PCMCIA
  # https://en.wikipedia.org/wiki/PC_Card
  # https://cateee.net/lkddb/web-lkddb/PCCARD.html
  CONFIG_PCCARD

  # https://www.kernelconfig.io/CONFIG_NOZOMI
  # HSDPA Broadband Wireless Data Card - Globe Trotter
  # Archaic wireless broadband card
  CONFIG_NOZOMI

  # https://www.kernelconfig.io/CONFIG_RC_CORE
  # Remote Controller support
  CONFIG_RC_CORE

  # https://www.kernelconfig.io/CONFIG_USB_GSPCA
  # GSPCA based webcams
  # https://www.kernel.org/doc/Documentation/admin-guide/media/gspca-cardlist.rst
  CONFIG_USB_GSPCA

  # https://www.kernelconfig.io/CONFIG_HAMRADIO
  # Amateur Radio support
  CONFIG_HAMRADIO

  # https://www.kernelconfig.io/CONFIG_MEDIA_RADIO_SUPPORT
  # AM/FM radio receivers/transmitters
  CONFIG_MEDIA_RADIO_SUPPORT

  # https://www.kernelconfig.io/CONFIG_MEDIA_DIGITAL_TV_SUPPORT
  # Enable digital TV support.
  # Say Y when you have a board with digital support or a board with
  # hybrid digital TV and analog TV.
  CONFIG_MEDIA_DIGITAL_TV_SUPPORT

  # https://www.kernelconfig.io/CONFIG_MEDIA_ANALOG_TV_SUPPORT
  # Enable analog TV support
  # Say Y when you have a TV board with analog support or with a
  # hybrid analog/digital TV chipset.
  CONFIG_MEDIA_ANALOG_TV_SUPPORT

  # https://www.kernelconfig.io/CONFIG_BLK_DEV_FD
  # Normal floppy disk support
  CONFIG_BLK_DEV_FD

  # https://www.kernelconfig.io/CONFIG_HID_PXRC
  # Support for PhoenixRC HID Flight Controller, a 8-axis flight controller.
  CONFIG_HID_PXRC

  # ADC with mismatched value that has to be set directly
  # https://www.kernelconfig.io/CONFIG_VIDEO_CS3308
  CONFIG_VIDEO_CS3308

  # AVE with mismatched value that has to be set directly
  # https://www.kernelconfig.io/CONFIG_VIDEO_SAA6752HS
  CONFIG_VIDEO_SAA6752HS

  # https://www.kernelconfig.io/CONFIG_GNSS
  # https://en.wikipedia.org/wiki/Satellite_navigation
  # https://www.kernel.org/doc/Documentation/devicetree/bindings/gnss/gnss-common.yaml
  # GNSS receiver support
  CONFIG_GNSS

  # https://www.kernelconfig.io/CONFIG_GPIB
  # https://en.wikipedia.org/wiki/GPIB
  # Enable support for GPIB cards and dongles.
  CONFIG_GPIB


  ############################################################
  ################# Attack surface reduction #################
  ############################################################
  # https://www.kernelconfig.io/CONFIG_DEVPORT
  # Provides support for the /dev/port device, which can RW directly to IO ports
  CONFIG_DEVPORT

  # https://cateee.net/lkddb/web-lkddb/LIVEPATCH.html
  # Attack surface, not useful with bootc 
  CONFIG_LIVEPATCH

  # https://cateee.net/lkddb/web-lkddb/X86_IOPL_IOPERM.html
  # Provides emulation for legacy syscalls that are already blocked by lockdown
  CONFIG_X86_IOPL_IOPERM

  # https://cateee.net/lkddb/web-lkddb/CACHESTAT_SYSCALL.html
  # Syscall that exposes page cache information, used primarily by DBMSes
  CONFIG_CACHESTAT_SYSCALL

  # https://cateee.net/lkddb/web-lkddb/MEM_SOFT_DIRTY.html
  # Adds a soft dirty bit to PTEs that can be cleared by userspace.
  # Used primarily by https://en.wikipedia.org/wiki/CRIU
  CONFIG_MEM_SOFT_DIRTY

  # https://www.kernelconfig.io/CONFIG_DEVMEM
  # Provides support for the /dev/mem device, which can RW directly to memory
  CONFIG_DEVMEM
  
  # https://cateee.net/lkddb/web-lkddb/STRICT_DEVMEM.html
  # https://cateee.net/lkddb/web-lkddb/IO_STRICT_DEVMEM.html
  # Fedora enables these but they depends on devmem, which we disable, so we must disable them too
  CONFIG_STRICT_DEVMEM
  CONFIG_IO_STRICT_DEVMEM

  # https://www.kernelconfig.io/CONFIG_KPROBES
  # https://www.kernelconfig.io/CONFIG_KPROBE_EVENTS
  # https://www.kernelconfig.io/CONFIG_KPROBES_SANITY_TEST
  # Everything KPROBE related. Kprobes are already disabled via lockdown
  # and are only used for kernel development
  CONFIG_KPROBES
  CONFIG_KPROBE_EVENTS
  CONFIG_KPROBES_SANITY_TEST

  # https://cateee.net/lkddb/web-lkddb/KGDB.html
  # Kernel debuggger, enabled by fedora, depends on kprobe
  CONFIG_KGDB_HONOUR_BLOCKLIST
  CONFIG_KGDB_LOW_LEVEL_TRAP
  CONFIG_KGDB_SERIAL_CONSOLE
  CONFIG_KGDB_TESTS
  CONFIG_KGDB

  # https://www.kernelconfig.io/CONFIG_PROC_KCORE
  # Exposes kernel text image layout in /proc/kcore
  CONFIG_PROC_KCORE

  # https://cateee.net/lkddb/web-lkddb/HIBERNATION.html
  # https://unix.stackexchange.com/a/591493
  # Already prevented by lockdown, substantial attack surface
  CONFIG_HIBERNATION

  # https://www.kernelconfig.io/CONFIG_EFI_TEST
  # EFI testing support
  CONFIG_EFI_TEST

  # https://www.kernelconfig.io/CONFIG_MMIOTRACE
  # MMIO access for debugging
  CONFIG_MMIOTRACE

  # https://cateee.net/lkddb/web-lkddb/KEXEC.html
  # https://cateee.net/lkddb/web-lkddb/KEXEC_FILE.html
  # Kexec, already disabled via sysctl
  CONFIG_KEXEC
  CONFIG_KEXEC_FILE
  CONFIG_KEXEC_HANDOVER_DEBUGFS
  CONFIG_KEXEC_HANDOVER
  CONFIG_KEXEC_JUMP

  # https://cateee.net/lkddb/web-lkddb/LIVEUPDATE_MEMFD.html
  # Depends on KEXEC, enabled by Fedora
  CONFIG_LIVEUPDATE
  CONFIG_LIVEUPDATE_MEMFD

  # https://cateee.net/lkddb/web-lkddb/CRASH_DUMP.html
  # Crash dump support for kernel debugging, depends on kexec
  CONFIG_CRASH_DUMP

  # https://cateee.net/lkddb/web-lkddb/PRESERVE_FA_DUMP.html
  # PPC only, build complains about this if crash dumps are disabled
  CONFIG_PRESERVE_FA_DUMP

  # https://cateee.net/lkddb/web-lkddb/PROC_VMCORE.html
  # Used by kdump, a kernel debugging tool which depends on kexec
  CONFIG_PROC_VMCORE

  # https://cateee.net/lkddb/web-lkddb/CRASH_DM_CRYPT.html
  # Enables writing crash dumps to an encrypted disk volume.
  # Useless when crash dumps are already disabled
  CONFIG_CRASH_DM_CRYPT

  # https://cateee.net/lkddb/web-lkddb/EFI_CUSTOM_SSDT_OVERLAYS.html
  # https://cateee.net/lkddb/web-lkddb/ACPI_TABLE_UPGRADE.html
  # Various ACPI modification functionality that's already blocked by lockdown
  CONFIG_EFI_CUSTOM_SSDT_OVERLAYS
  CONFIG_ACPI_TABLE_UPGRADE

  # Asynchronous Transfer Mode
  # https://www.kernelconfig.io/CONFIG_ATM
  # Already blocked at runtime: https://github.com/secureblue/secureblue/blob/live/files/system/usr/lib/modprobe.d/secureblue.conf#L26
  CONFIG_ATM

  # Legacy parallel port support
  # https://www.kernelconfig.io/CONFIG_PARPORT
  # Already blocked at runtime: https://github.com/secureblue/secureblue/blob/live/files/system/usr/lib/modprobe.d/secureblue.conf#L183
  CONFIG_PARPORT

  # Legacy game port support
  # And all joystick modules aside from xpad 
  # https://cateee.net/lkddb/web-lkddb/GAMEPORT.html
  # Already blocked at runtime: https://github.com/secureblue/secureblue/blob/live/files/system/usr/lib/modprobe.d/secureblue.conf#L195
  CONFIG_GAMEPORT
  CONFIG_JOYSTICK_A3D
  CONFIG_JOYSTICK_ADC
  CONFIG_JOYSTICK_ADI
  CONFIG_JOYSTICK_ANALOG
  CONFIG_JOYSTICK_AS5011
  CONFIG_JOYSTICK_COBRA
  CONFIG_JOYSTICK_DB9
  CONFIG_JOYSTICK_FSIA6B
  CONFIG_JOYSTICK_GAMECON
  CONFIG_JOYSTICK_GF2K
  CONFIG_JOYSTICK_GRIP
  CONFIG_JOYSTICK_GRIP_MP
  CONFIG_JOYSTICK_GUILLEMOT
  CONFIG_JOYSTICK_IFORCE_232
  CONFIG_JOYSTICK_IFORCE
  CONFIG_JOYSTICK_IFORCE_USB
  CONFIG_JOYSTICK_INTERACT
  CONFIG_JOYSTICK_JOYDUMP
  CONFIG_JOYSTICK_MAGELLAN
  CONFIG_JOYSTICK_PSXPAD_SPI_FF
  CONFIG_JOYSTICK_PSXPAD_SPI
  CONFIG_JOYSTICK_PXRC
  CONFIG_JOYSTICK_QWIIC
  CONFIG_JOYSTICK_SEESAW
  CONFIG_JOYSTICK_SENSEHAT
  CONFIG_JOYSTICK_SIDEWINDER
  CONFIG_JOYSTICK_SPACEBALL
  CONFIG_JOYSTICK_SPACEORB
  CONFIG_JOYSTICK_STINGER
  CONFIG_JOYSTICK_TMDC
  CONFIG_JOYSTICK_TURBOGRAFX
  CONFIG_JOYSTICK_TWIDJOY
  CONFIG_JOYSTICK_WALKERA0701
  CONFIG_JOYSTICK_WARRIOR
  CONFIG_JOYSTICK_ZHENHUA
)

for config_to_disable in "${configs_to_disable[@]}"; do
  echo "# ${config_to_disable} is not set" >> kernel-local
done

for config_to_enable in "${configs_to_enable[@]}"; do
  echo "${config_to_enable}=y" >> kernel-local
done

sed --sandbox -i \
  -e "s/^# define buildid .*/%define buildid .secureblue.${secureblue_buildid_version}/" \
  kernel.spec

# Merge trusted-keys/* into secureblue-certs.pem. This gets appended to
# certs/rhel.pem alongside Fedora's keys (see trusted-keys.patch), so they
# all end up in CONFIG_SYSTEM_TRUSTED_KEYS and thus .builtin_trusted_keys.
cat "${script_dir}"/trusted-keys/*.pem > secureblue-certs.pem

cp "${script_dir}/correct-spectre-flag-behavior.patch" .

git apply "${script_dir}"/patches/*.patch

mv ./* "${build_dir}"
