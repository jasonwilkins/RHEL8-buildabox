#!/bin/bash
#This script copies only the currently installed RPMs into the packages directory and automatically sorts them into correct repo - only baseos and appstream currently supported.
#Sept 2024
#https://github.com/jasonwilkins/RHEL8-buildabox
#Initial Public Release
#Run from /root
#
#Make sure you run it from an installation that was from a custom kickstart with all the packages you need.
#
clear
echo -e "\033[1;33m------WARNING WARNING WARNING------\033[0m"
echo -e "This script will re-establish and re-size the development environment in /root/buildabox."
echo -e "It should only be ran after the first installation of the custom iso.  It will copy currently installed RPMs only!"
echo -e "root access is required and the full size iso must be available."
echo -e "/root/buildabox will be DELETED - DO NOT RUN THIS FROM /root/buildabox!"
[ -z "$(blkid /dev/sr0)" ] && { echo -e "\n\033[1;33mLooks like you don't have the cdrom drive connected...Check hypervisor settings and try again.\n\033[0m"; exit; }
[[ $PWD/ = /mnt/cdrom/ ]] && { clear; echo -e "\n\033[1;31mDo not run from /mnt/cdrom.  Copy to /root.\n\033[0m"; exit 1; }
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
#Reset cdrom mount point
umount /mnt/cdrom
rm -rf /mnt/cdrom
mkdir /mnt/cdrom
mount /dev/sr0 /mnt/cdrom
[[ $PWD/ = /root/buildabox/ ]] && { clear; echo -e "\n\033[1;31mI told you not to run this script from /root/buildabox!\n\033[0m"; exit 1; }
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
yum install -y rsync createrepo nano vim dos2unix zip 2>&1 > /dev/null
#
echo -e "\n\033[1;33mCopying base directory structure...\033[0m"
rm -rf /root/buildabox
mkdir /root/buildabox
rsync -a --info=progress2 /mnt/cdrom/ /root/buildabox/ --exclude BaseOS --exclude AppStream
#mkdir -p /root/buildabox/AppStream/Packages /root/buildabox/BaseOS/Packages
echo -e "\n\033[1;33mCopying and sorting only currently installed rpms from install media...\033[0m"
# Define the parent directory containing both BaseOS and AppStream folders
parent_dir="/mnt/cdrom"
rm -f /root/copy-errors.txt
touch /root/copy-errors.txt
chmod 660 /root/copy-errors.txt
# Define the destination directories for BaseOS and AppStream RPMs
baseos_dest_dir="/root/buildabox/BaseOS/Packages"
appstream_dest_dir="/root/buildabox/AppStream/Packages"
# Create the destination directories if they don't exist
mkdir -p "$baseos_dest_dir"
mkdir -p "$appstream_dest_dir"
#
# List all installed packages and loop through them
rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}.rpm\n' | while read -r package_name; do
# Search for the RPM in the parent directory, in both BaseOS and AppStream subdirectories
rpm_file=$(find "$parent_dir" -type f -name "$package_name" 2>/dev/null)
  if [[ -n "$rpm_file" ]]; then
    # Determine if the file was found in BaseOS or AppStream
    if [[ "$rpm_file" == *"/BaseOS/"* ]]; then
      # Copy to BaseOS destination folder
      echo -ne "\r\033[2KCopying BaseOS RPM: $package_name"
      cp "$rpm_file" "$baseos_dest_dir/"
    elif [[ "$rpm_file" == *"/AppStream/"* ]]; then
      # Copy to AppStream destination folder
      echo -ne "\r\033[2KCopying AppStream RPM: $package_name"
      cp "$rpm_file" "$appstream_dest_dir/"
    else
      echo -e "\nThe package was found, but not in BaseOS or AppStream. Skipping..."
	  echo $rpm_file was found but I dont know what to do with it! >> /root/copy-errors.txt
    fi
  else
    # If no matching RPM is found
    echo -e "\nNo matching RPM found for package $package_name"
    echo $package_name is installed but could not be found in the source directory! >> /root/copy-errors.txt
  fi
done
#
echo -e "\033[1;33m\n\nCompleted copying matching RPM files.  \033[1;32mCheck /root/copy-errors.txt to ensure no errors\033[0m"
#
#Create repos from here:
#Delete old stuff
echo -e "\033[1;33m\nRecreating repo data...\033[0m"
rm -f /root/buildabox/BaseOS/comps_base.xml
rm -rf /root/buildabox/BaseOS/repodata/
rm -f /root/buildabox/AppStream/comps_app.xml
rm -f /root/buildabox/AppStream/modules.yaml
rm -rf /root/buildabox/AppStream/repodata
#Create restructured repo based on original full redhat files
cp /root/buildabox/original-repodata/comps-BaseOS.x86_64.xml /root/buildabox/BaseOS/
cp /root/buildabox/original-repodata/comps-AppStream.x86_64.xml /root/buildabox/AppStream/
cd /root/buildabox
createrepo -g comps-BaseOS.x86_64.xml BaseOS/
createrepo -g comps-AppStream.x86_64.xml AppStream/
cp /root/buildabox/original-repodata/modules.yaml /root/buildabox/AppStream/
modifyrepo_c --mdtype=modules AppStream/modules.yaml AppStream/repodata/
echo -e "\033[1;32m\\nResize completed.  Please rerun the rebuild.sh script from the /root/buildabox directory.\033[0m\n"
