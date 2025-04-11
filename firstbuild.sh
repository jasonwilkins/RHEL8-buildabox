#!/bin/bash
#Sets up the first build environment for the iso creation.
#Sept 2024
#https://github.com/jasonwilkins/RHEL8-buildabox
#Initial Public Release
#Run from /root
#
#This script needs to be ran immediately after the first install of the Red Hat OS.
#Its intention is to setup the first dev environment.
#It also sets up the local repo for installing tools you may need or prefer.
#It copies all RPMs and builds a full size image, we need this right before we trim down after the 2nd install.
#
clear
echo -e "\033[1;33m------WARNING WARNING WARNING------\033[0m"
echo -e "This script will establish or reset the buildabox development environment in /root/buildabox."
echo -e "Existing buildabox and incoming directories will be deleted."
echo -e "DO NOT RUN THIS FROM /root/buildabox!\n"
echo -e "It should only be ran after the first installation from the original Red Hat iso, but can be ran multiple times."
echo -e "root access is required and the original full size Red Hat iso must be available on /dev/sr0."
echo -e "***Check 'connected' setting for the CDROM drive in hypervisor if you have problems mounting /mnt/cdrom."
# Check cdrom status
[ -z "$(blkid /dev/sr0)" ] && { echo -e "\n\033[1;33mLooks like you don't have the cdrom drive connected...Check hypervisor settings and try again.\n\033[0m"; exit; }
# Proceed?
while true; do
  read -p $'\n\e[31mProceed\e[0m [y/N] : ' answer
  case ${answer:-no} in
    [Yy][Ee][Ss] | [Yy] )
      # If the answer is yes, execute your command
      echo -e "\033[1;33m\nProceeding with setup of development environment...\033[0m"
      break
      ;;
    [Nn][Oo] | [Nn] )
      # If the answer is no or default, do nothing
      echo -e "\n\033[1;33mCanceled.\n\033[0m"
      exit
      break
      ;;
    * )
      # If input is invalid, prompt again
      echo "Please answer yes or no."
      ;;
  esac
done
#
if [ $(id -u) -ne 0 ]
  then echo "Need to be root or sudo..."
  exit
fi
#
[[ $PWD/ = /root/buildabox/ ]] && { clear; echo -e "\n\033[1;31mI told you not to run this script from /root/buildabox!\n\033[0m"; exit 1; }
#
[ -z "$(ls /mnt/ | grep cdrom)" ] && mkdir /mnt/cdrom
[ -z "$(findmnt /dev/sr0)" ] && mount /dev/sr0 /mnt/cdrom
rm -rf /root/buildabox
mkdir /root/buildabox
#Setup local install source...
echo -e "\n\033[1;33mSetting up a local installation repository...\033[0m"
rm -rf /etc/yum.repos.d/*
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
chmod 644 /etc/yum.repos.d/local.repo
dnf clean all 2>&1 > /dev/null
sleep 2
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
#
echo -e "\n\033[1;33mInstalling buildabox support programs...\033[0m"
yum install -y genisoimage isomd5sum mtools syslinux pykickstart 2>&1 > /dev/null
yum install -y rsync nano vim dos2unix zip 2>&1 > /dev/null
echo -e "\n\033[1;33mCopying base directory structure...\033[0m"
shopt -s dotglob
rsync -a --info=progress2 /mnt/cdrom/ /root/buildabox/
#Setup rebuild destination directory
rm -rf /opt/incoming/
mkdir /opt/incoming/
#Setup a copy of the original repo so we can rebuild from it later
echo -e "\n\033[1;33mBuilding Repository Data Source...\033[0m"
mkdir /root/buildabox/original-repodata
cp /mnt/cdrom/BaseOS/repodata/*-comps*.xml /root/buildabox/original-repodata/comps-BaseOS.x86_64.xml
cp /mnt/cdrom/AppStream/repodata/*-comps*.xml /root/buildabox/original-repodata/comps-AppStream.x86_64.xml
cp /mnt/cdrom/AppStream/repodata/*-modules* /root/buildabox/original-repodata/
gzip -d /root/buildabox/original-repodata/*-modules.yaml.gz
mv /root/buildabox/original-repodata/*-modules.yaml /root/buildabox/original-repodata/modules.yaml
#
echo -e "\n\033[1;32m------Build Compelte, please check for errors------\n\033[0m"
echo -e "\033[1;33mNext steps are to:\033[0m\nCopy new kickstart file to /root/buildabox and customize\nModify /root/buildabox/EFI/BOOT/grub.cfg\n"
