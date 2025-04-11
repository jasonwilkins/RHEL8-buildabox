#!/bin/bash
#Local creation of BaseOS and AppStream repos so you can install RPMs from the offline iso.
#Sept 2024
#https://github.com/jasonwilkins/RHEL8-buildabox
#Initial Public Release
#Run from anywhere
#
#Make sure your cdrom is connected in hypervisor and mountable on /mnt/cdrom.
#
clear
#Clear out the local mount points
umount /mnt/cdrom
rm -rf /mnt/cdrom
mkdir /mnt/cdrom
mount /dev/sr0 /mnt/cdrom
#Disable subscription manager and remove repo files
printf 'Cleaning out existing repos...\n'
subscription-manager config --rhsm.manage_repos=0
rm -rf /etc/yum.repos.d/*
printf 'Creating new repo file\n'
#Create new configuration, leave enabled for now
cat << EOF > /etc/yum.repos.d/local.repo
[InstallMedia-BaseOS]
name=Red Hat Enterprise Linux 8 - BaseOS
metadata_expire=-1
gpgcheck=1
enabled=1
baseurl=file:///mnt/cdrom/BaseOS/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

[InstallMedia-AppStream]
name=Red Hat Enterprise Linux 8 - AppStream
metadata_expire=-1
gpgcheck=1
enabled=1
baseurl=file:///mnt/cdrom/AppStream/
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
EOF
#
printf 'Resetting subscription and updating database\n'
chmod 644 /etc/yum.repos.d/local.repo
dnf clean all
