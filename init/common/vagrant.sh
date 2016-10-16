#!/bin/sh -eux

## common/metadata.sh
mkdir -p /etc
cp /tmp/bento-metadata.json /etc/bento-metadata.json
chmod 0444 /etc/bento-metadata.json
rm -f /tmp/bento-metadata.json


## common/vagrant.sh
pubkey_url="https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub"
mkdir -p /home/vagrant/.ssh
if command -v wget > /dev/null 2>&1 ; then
    wget --no-check-certificate -O /home/vagrant/.ssh/authorized_keys "$pubkey_url" ;
elif command -v curl > /dev/null 2>&1 ; then
    curl --insecure --location -o /home/vagrant/.ssh/authorized_keys "$pubkey_url" ;
elif command -v aria2c > /dev/null 2>&1 ; then
    aria2c --check-certificate=false -d / -o /home/vagrant/.ssh/authorized_keys "$pubkey_url" ;
elif command -v fetch > /dev/null 2>&1 ; then
    fetch --retry --mirror --no-verify-peer -o /home/vagrant/.ssh/authorized_keys "$pubkey_url" ;
elif command -v ftp > /dev/null 2>&1 ; then
    ftp -S dont -o /home/vagrant/.ssh/authorized_keys "$pubkey_url" ;
else
    echo "Cannot download vagrant public key" ;
    exit 1 ;
fi
chown -R vagrant:$(id -gn vagrant) /home/vagrant
chown -R vagrant:$(id -gn vagrant) /home/vagrant/.ssh
chmod -R go-rwsx /home/vagrant/.ssh
cp /home/$(id -un)/.vbox_version /home/vagrant/
