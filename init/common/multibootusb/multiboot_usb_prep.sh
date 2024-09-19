#!/bin/bash -x

set -x
DEVX=${DEVX:-sdb}

_sgdisk_usbdrv() {
  sgdisk --zap-all /dev/${DEVX} ; sgdisk --clear --mbrtogpt /dev/${DEVX}
  sgdisk --new 1:1M:+1M --typecode 1:ef02 --change-name 1:"bios_boot" /dev/${DEVX}
  sgdisk --new 2:0:+200M --typecode 2:ef00 --change-name 2:"ESP" /dev/${DEVX}
  sgdisk --new 3:0:0 --typecode 3:8300 --change-name 3:"MULTI_ISOS" /dev/${DEVX}

  sync ; sgdisk --print /dev/${DEVX} ; sgdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary || partprobe
}
_sfdisk_usbdrv() {
  sfdisk --delete --wipe always /dev/${DEVX}
  echo -n 'label: gpt' | sfdisk /dev/${DEVX}
  # [s]fdisk type(s) (fdisk /dev/sdX; l):
  # shortcut | MBR | GPT
  #          |  4  | 21686148-6449-6E6F-744E-656564454649 (BIOS boot)
  #  U(EFI)  | EF  | C12A7328-F81F-11D2-BA4B-00A0C93EC93B
  #  L(inux) default | 83 | 0FC63DAF-8483-4772-8E79-3D69D8477DE4
  #          | 11  | EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 (msftdata)
  echo -n start=1MiB,size=1MiB,bootable,type=21686148-6449-6E6F-744E-656564454649,name=bios_boot | sfdisk -N 1 /dev/${DEVX}
  echo -n size=200MiB,bootable,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B,name=ESP | sfdisk -N 2 \
    /dev/${DEVX}
  echo -n type=0FC63DAF-8483-4772-8E79-3D69D8477DE4,name=MULTI_ISOS | sfdisk -N 3 /dev/${DEVX}

  sfdisk -N 1 --part-label bios_boot /dev/${DEVX}
  sfdisk -N 2 --part-label ESP /dev/${DEVX}
  sfdisk -N 3 --part-label MULTI_ISOS /dev/${DEVX}

  sync ; sfdisk --list /dev/${DEVX} ; sleep 3 ; sfdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary || partprobe
}
_parted_usbdrv() {
  parted --script /dev/${DEVX} mklabel gpt
  DIFF=1 ; END='-0'
  # /dev/${DEVX}: for BIOS 1M none (bios_boot) ; for EFI 200M fat32 (ESP)
  END=$(( 1 + ${DIFF} ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ${DIFF} ${END} name 1 bios_boot

  DIFF=${END} ; END=$(( 200 + ${DIFF} ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary fat32 ${DIFF} ${END} name 2 ESP

  DIFF=${END} ; END=100%
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 ${DIFF} ${END} name 3 MULTI_ISOS

  parted -s /dev/${DEVX} set 1 bios_grub on
  parted -s /dev/${DEVX} set 2 esp on

  sync ; parted -s /dev/${DEVX} unit GiB print ; sleep 3
  parted -s /dev/${DEVX} align-check optimal 1 ; sleep 3
  sleep 3 ; partprobe --summary || partprobe
}

part_usbdrv() {
  TOOL=${1:-sgdisk}
  case ${TOOL} in
    'sfdisk') _sfdisk_usbdrv ;;
    'parted') _parted_usbdrv ;;
    *) _sgdisk_usbdrv ;;
  esac
}

mkfs_usbdrv_volumes() {
  #gdisk ${DEVX}
  #> Command (? for help): r
  #> Recovery/transformation: h
  #> Type from 1 to 3 GPT partition numbers: 1 2 3
  #> Place EFI GPT (0xEF) first in MBR (Y/N): N
  #
  #> Create entry for GPT part #1 (MBR part #2)
  #  Enter an MBR hex code (default EF):
  #  Set the bootable flag? (Y/N): N
  #> Create entry for GPT part #2 (MBR part #3)
  #  Enter an MBR hex code (default EF):
  #  Set the bootable flag? (Y/N): N
  #> Create entry for GPT part #3 (MBR part #4)
  #  Enter an MBR hex code (default 83):
  #  Set the bootable flag? (Y/N): Y
  #
  #> Recovery/transformation: x
  #  Expert command: h
  #  Expert command: w
  #> Final checks complete ...
  #> Do you want to proceed? (Y/N): Y
  sgdisk --hybrid 1:2:3 /dev/${DEVX}
  #sgdisk --attributes 3:set:2 /dev/${DEVX}
  #sfdisk --part-attrs /dev/${DEVX} 3 LegacyBIOSBootable
  parted /dev/${DEVX} set 3 legacy_boot on set 3 msftdata on
  sleep 3

  #sgdisk --print /dev/${DEVX} ; sgdisk --print-mbr /dev/${DEVX} ; sgdisk --verify /dev/${DEVX}
  #sfdisk --list /dev/${DEVX} ; sfdisk --verify /dev/${DEVX}
  parted /dev/${DEVX} unit GiB print ; parted -s /dev/${DEVX} align-check optimal 1
  sleep 3

  #DEV_ESP=$(blkid /dev/${DEVX} | grep -e ESP | cut -d: -f1)
  DEV_ESP=$(lsblk -nlpo name,partlabel /dev/${DEVX} | grep -e ESP | cut -d' ' -f1)
  DEV_ISOS=$(lsblk -nlpo name,partlabel /dev/${DEVX} | grep -e MULTI_ISOS | cut -d' ' -f1)
  yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sync ; sleep 3
  yes | mkfs.ext2 -L isos ${DEV_ISOS} ; sync ; sleep 3
}

grub_bios_efi_install() {
  DEV_ESP=$(lsblk -nlpo name,partlabel /dev/${DEVX} | grep -e ESP | cut -d' ' -f1)
  DEV_ISOS=$(lsblk -nlpo name,partlabel /dev/${DEVX} | grep -e MULTI_ISOS | cut -d' ' -f1)
  mkdir -p /mnt/ISOS ; mount ${DEV_ISOS} /mnt/ISOS
  mkdir -p /mnt/ISOS/boot/efi ; mount ${DEV_ESP} /mnt/ISOS/boot/efi

  grub-install --target=x86_64-efi --efi-directory=/mnt/ISOS/boot/efi --boot-directory=/mnt/ISOS/boot --removable --recheck
  ls -R /mnt/ISOS/boot/efi ; sleep 3
  cp /mnt/ISOS/boot/efi/EFI/BOOT/BOOTX64.EFI /mnt/ISOS/boot/efi/EFI/BOOT/BOOTX64.EFI.bak
  cp /mnt/ISOS/boot/efi/EFI/BOOT/grubx64.efi /mnt/ISOS/boot/efi/EFI/BOOT/BOOTX64.EFI
  grub-install --target=i386-pc --boot-directory=/mnt/ISOS/boot --recheck /dev/${DEVX}

  umount /mnt/ISOS/boot/efi ; rm -r /mnt/ISOS/boot/efi
  umount /mnt/ISOS ; rm -r /mnt/ISOS
}

${@}
