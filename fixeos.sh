#!/bin/bash

export LIBGUESTFS_BACKEND_SETTINGS=force_tcg

rm -rf /mnt/knecht
mkdir /mnt/knecht

if [[ $# -eq 0 ]]
then
    echo "Please specify directory with image"
    exit 1
fi
if [[ ! -f $1/hda.qcow2 ]]
then
    echo "File $1/hda.qcow2 not found"
    exit 1
fi
# for vEOS < 4.21 mount /dev/sda1, else /dev/sda2
echo "Editing $1/hda.qcow2"
if [[ ${1:7:2} -lt 21 ]]
then
    guestmount -a $1/hda.qcow2 -m /dev/sda1 /mnt/knecht
else
    guestmount -a $1/hda.qcow2 -m /dev/sda2 /mnt/knecht
fi

echo  "" > /mnt/knecht/startup-config
cat <<EOT >> /mnt/knecht/startup-config
hostname vEOS
!
spanning-tree mode mstp
!
aaa authorization exec default local
!
service routing protocols model multi-agent
!
no aaa root
!
username admin privilege 15 role network-admin secret 0 admin
!
interface Management1
   ip address dhcp
!
ip routing
!
management api http-commands
   protocol http
   protocol unix-socket
   no shutdown
EOT
# if public key exists on local host, add it to VM config
# also accounts for CLI changes after EOS 4.23 - "ssh-key" instead of "sshkey"
if [[ -f ~/.ssh/id_rsa.pub ]]
then
    if [[ ${1:7:2} -lt 23 ]]
    then
        echo "username admin sshkey `cat ~/.ssh/id_rsa.pub`" >> /mnt/knecht/startup-config
    else
        echo "username admin ssh-key `cat ~/.ssh/id_rsa.pub`" >> /mnt/knecht/startup-config
    fi
fi

guestunmount /mnt/knecht
