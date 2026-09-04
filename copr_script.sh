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

  # Enable control flow integrity.
  CONFIG_CFI

  # Normalizes the CFI tags for integer types across C and Rust.
  # Needs to be enabled as Fedora sets CONFIG_RUST=y.
  CONFIG_CFI_ICALL_NORMALIZE_INTEGERS
)

configs_to_disable=(
  # Do not use FineIBT by default; use KCFI instead. Same as the cfi=kcfi karg.
  # FineIBT has had a history of vulnerabilities and KCFI is more robust.
  CONFIG_CFI_AUTO_DEFAULT

  # Panic on CFI violations, as permissive mode is for development use only.
  CONFIG_CFI_PERMISSIVE

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

  # https://www.kernelconfig.io/CONFIG_NOZOMI
  # HSDPA Broadband Wireless Data Card - Globe Trotter
  # Archaic wireless broadband card
  CONFIG_NOZOMI

  # https://www.kernelconfig.io/CONFIG_RC_CORE
  # Remote Controller support
  CONFIG_RC_CORE

  # https://www.kernelconfig.io/CONFIG_IIO
  # The industrial I/O subsystem provides a unified framework for
  # drivers for many different types of embedded sensors using a
  # number of different physical interfaces (i2c, spi, etc).
  CONFIG_IIO

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

git apply "${script_dir}"/patches/*.patch

mv ./* "${build_dir}"
