#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

set -x
export MIRROR=${MIRROR:-dl-cdn.alpinelinux.org/alpine}
export GRP_NM=${GRP_NM:-vg0}

#export PASSWD_PLAIN=${1:-packer}
export PASSWD_CRYPTED=${1:-\$6\$16CHARACTERSSALT\$A4i3yeafzCxgDj5imBx2ZdMWnr9LGzn3KihP9Dz0zTHbxw31jJGEuuJ6OB6Blkkw0VSUkQzSjE9n4iAAnl0RQ1}

service sshd stop

#RELEASE=${RELEASE:-latest-stable}

DEV_ROOT=$(blkid | grep -e "${GRP_NM}-osRoot" | cut -d: -f1)
#DEV_ROOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osRoot" | cut -d' ' -f1)
mount /dev/sda3 /mnt ; sync
#mount ${DEV_ROOT} /mnt ; sync

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
apk add bash sudo util-linux shadow openssh # efibootmgr
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
fstrim -av
sync

exit

EOFchroot
# end chroot commands

tar -xf /tmp/scripts.tar -C /mnt/root/ ; sleep 5

read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
  sync ; swapoff -va ; umount -vR /mnt ;
  reboot ; #poweroff ;
fi
