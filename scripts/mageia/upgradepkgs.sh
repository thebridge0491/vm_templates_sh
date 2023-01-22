#!/bin/sh -eux

## scripts/upgradepkgs.sh
MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/mageia}

set +e

#urpmq --list-url ; sleep 5
#urpmi.update -a ; urpmi --auto-update
dnf repolist enabled ; sleep 5
dnf -y check-update ; dnf -y upgrade
#urpmi --no-recommends sudo
dnf -y --setopt=install_weak_deps=False install sudo
dnf versionlock list ; sleep 3

dnf -y clean all
fstrim -av
if command -v btrfs > /dev/null ; then
  btrfs subvolume list / ;
elif command -v lvcreate > /dev/null ; then
  lvs ;
fi
sleep 5 ; sync
