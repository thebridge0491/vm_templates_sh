#!/bin/sh -eux

dd bs=4M if=/dev/zero of=/EMPTY || echo "dd exit code $? is suppressed"
dd bs=4M if=/dev/zero of=/var/tmp/EMPTY || echo "dd exit code $? is suppressed"
dd bs=4M if=/dev/zero of=/home/EMPTY || echo "dd exit code $? is suppressed"

rm -f /home/EMPTY ; rm -f /var/tmp/EMPTY ; rm -f /EMPTY
sync  # Block until the empty file(s) has been removed

set +e
swapuuid="$(blkid -o value -l -s UUID -t TYPE=swap)"
swaplabel="$(blkid -o value -l -s LABEL -t TYPE=swap)"
swapdev="$(blkid -o device -l -t TYPE=swap)"
case "$?" in
    2|0) ;;
    *) exit 1 ;;
esac

if [ "x${swapuuid}" != "x" ] ; then
    swappart="$(readlink -f $swapdev)" ;
    swapoff "$swappart" ;
    dd bs=4M if=/dev/zero of="$swappart" || echo "dd exit code $? is suppressed" ;
    mkswap -L "$swaplabel" -U "$swapuuid" "$swappart" ; 
    partprobe --summary ; sync ; swapon -a ;
fi
set -e

# display discard capabilities for device(s)
#lsblk -o MOUNTPOINT,DISC-MAX,FSTYPE
#lsblk --discard

# manually trim(discard) unused filesys blocks
#fstrim -av
