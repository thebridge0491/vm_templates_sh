#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

set -x

export VOL_MGR=${VOL_MGR:-std}
export GRP_NM=${GRP_NM:-vg0}
export MIRROR=${MIRROR:-dl-cdn.alpinelinux.org/alpine}
#export RELEASE=${RELEASE:-latest-stable}

service sshd stop


remount_filesys() {
  echo "Re-mount filesystems" ; sleep 3
  DEV_ROOT=$(blkid | grep -e "${GRP_NM}-osRoot" | cut -d: -f1)
  #DEV_ROOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osRoot" | cut -d' ' -f1)

  if [ "lvm" = "$VOL_MGR" ] ; then
    mount /dev/mapper/vg0-lv_root /mnt ;
  else
    mount /dev/sda3 /mnt ;
  fi
  #mount ${DEV_ROOT} /mnt
  sync
}

system_config() {
  #export PASSWD_PLAIN=${1:-packer}
  export PASSWD_CRYPTED=${1:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

  cat << EOFchroot | LANG=en_US.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

service sshd stop

mkdir -p /etc/apk
. /etc/os-release
RELEASE=\$(cat /etc/alpine-release | cut -d. -f1-2)
sed -i '/cdrom/ s|^|#|' /etc/apk/repositories
echo "http://${MIRROR}/v\${RELEASE}/main" >> /etc/apk/repositories
#echo "http://${MIRROR}/${RELEASE}/main" >> /etc/apk/repositories
echo "http://${MIRROR}/v\${RELEASE}/community" >> /etc/apk/repositories
apk update
cat /etc/apk/repositories ; sleep 5

echo "Add software package selection(s)" ; sleep 3
apk add bash sudo mkpasswd util-linux shadow openssh # efibootmgr
#apk add xfce4
sleep 5

echo "Add user" ; sleep 3
#DIR_MODE=0750
useradd -m -g users -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PASSWD_PLAIN}" | chpasswd
echo -n 'packer:${PASSWD_CRYPTED}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat > /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#
#EOF
#chmod 0440 /etc/sudoers.d/99_packer
sleep 5


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


#echo "Temporarily permit root login via ssh password" ; sleep 3
#sed -i "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config


echo "Enable SSH service"
rc-update add sshd default


apk -v cache clean

mkpasswd -m help ; sleep 10

snapshot_name=\${ID}_install-\$(date "+%Y%m%d")

if [ "lvm" = "$VOL_MGR" ] ; then
  lvcreate --snapshot --size 2G --name \${snapshot_name} ${GRP_NM}/osRoot ;
  lvs ;
fi
sleep 5 ; fstrim -av
sync

exit

EOFchroot
# end chroot commands
}

unmount_reboot() {
  read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
  if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
    sync ; swapoff -va ; umount -vR /mnt ;
    reboot ; #poweroff ;
  fi
}

run_postinstall() {
  #PASSWD_PLAIN=${1:-}
  PASSWD_CRYPTED=${1:-}

  remount_filesys
  system_config $PASSWD_CRYPTED
  unmount_reboot
}

#----------------------------------------
$@
