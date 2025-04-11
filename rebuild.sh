#!/bin/bash
#Create the ISO from the /root/buildabox environment, make bootable, add md5 integrity hash.
#Sept 2024
#https://github.com/jasonwilkins/RHEL8-buildabox
#Initial Public Release
#Run from /root/buildabox
#
#Function to check if input is numeric and up to 4 digits
clear
echo -e "\033[1;34m----------->Build Script for custom Red Hat Enterprise Linux v8 iso\033[0m\n"
echo -e "\033[1;34m----------->Run from /root/buildabox\033[0m\n"
is_valid_number()
{
  re='^[0-9]{1,4}$'
  if [[ $1 =~ $re ]]; then
    return 0  # Valid
  else
    return 1  # Invalid
  fi
}
# Loop until valid input is provided
while true; do
  # Prompt user for input
  read -p "Enter version iteration of this iso: " number

  # Validate the input
  if is_valid_number "$number"; then
    break  # If valid, break the loop
  else
    echo -e "\033[1;31mError:\033[0m You must enter a valid number that is 1 to 4 digits long."
  fi
done
# Display valid input
echo -e "\033[1;33m\nCreating iso version:\033[0m $number"
#
[ -z "$(ls /opt/ | grep incoming)" ] && mkdir -p /opt/incoming
rm -f /opt/incoming/*.iso
rm -f /root/buildabox/.install-info.txt
echo "-->Build Script for custom RHELv8 iso<---" > /root/buildabox/.install-info.txt
echo -e "#\nInstallation version iteration: $number" >> /root/buildabox/.install-info.txt
current_datetime=$(date -u +"%A %d-%b-%Y %R %Z")
echo -e "Build date: $current_datetime" >> /root/buildabox/.install-info.txt
#Create iso file
mkisofs -o /opt/incoming/buildabox-custom-iso-v$number.iso -b isolinux/isolinux.bin -J -joliet-long -R -l -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e images/efiboot.img -no-emul-boot -graft-points -V "RHEL-8-10-0-BaseOS-x86_64" . 2>&1 | grep -v 'Using' | while IFS= read -r line; do
  echo -ne "\033[1K" && echo -ne "\r$line"
done
#Set archon access for file transfer
chown archon:archon /opt/incoming/*.iso
#Make bootable
echo -e "\033[1;33m\n\nSetting UEFI boot parameters...\033[0m"
isohybrid --uefi /opt/incoming/*.iso
#Implant MD5 hash for later verification
echo -e "\033[1;33m\nImplanting md5 for later mediacheck verification...\033[0m"
implantisomd5 /opt/incoming/*.iso
#For thorough folks...
echo -e "\033[1;33m\nGenerated md5 hash for download verification: \033[0m"
md5sum /opt/incoming/buildabox-custom-iso-v$number.iso
echo -e ""
# Run extended verification?  Same as mediacheck on install.
while true; do
  read -p "Run extended test of iso? [y/N]: " answer
  case ${answer:-no} in
    [Yy][Ee][Ss] | [Yy] )
      # If the answer is yes, execute your command
      echo -e "\033[1;33m\nRunning md5 verification...\033[0m"
      # Place your command here, e.g., ls or any other command
      checkisomd5 /opt/incoming/buildabox-custom-iso-v$number.iso --verbose
      break
      ;;
    [Nn][Oo] | [Nn] )
      # If the answer is no or default, do nothing
      echo -e "\033[1;33miso file not checked, it's probably fine...\033[0m"
      break
      ;;
    * )
      # If input is invalid, prompt again
      echo "Please answer yes or no."
      ;;
  esac
done
echo -e "\033[1;32m\nOutput file is: \033[0m/opt/incoming/buildabox-custom-iso-v$number.iso"
echo -e '\033[1;32mReady for download!\033[0m\n'
