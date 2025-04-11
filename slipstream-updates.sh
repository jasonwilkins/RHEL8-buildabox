#!/bin/bash
#Compare updated RPM files and if newer, copy to their respective repo folder.
#Sept 2024
#https://github.com/jasonwilkins/RHEL8-buildabox
#Initial Public Release
#Should be ran from /root/buildabox
#
#This script will check the UPDATES_DIR for rpms then compare those to our dev environment rpm store.
#It will compare the queried name of the rpm and build dates.  I don't use versions because rpm versions are inscrutable nonsense.
#If the name of the rpm matches, it checks the build date, then copies if newer and deletes the old rpm.  Neat and tidy!
#Hopefully no issues arise from using actual build dates instead of version, but who can say...Good luck!
#
#Directories
UPDATES_DIR="/opt/incoming/updates"
SEARCH_DIR="/root/buildabox"
thedate=$(date '+%d%b%Y-%H%M%S')
LOG_FILE="/root/slipstream-log-$thedate.txt"
#
touch $LOG_FILE
# Loop through each RPM in the updates directory
for update_rpm in "$UPDATES_DIR"/*.rpm; do
    # Get the package name and build date from the update RPM
    update_name=$(rpm -qip "$update_rpm" | awk '/^Name        :/ {print $3}')
    update_builddate=$(rpm -qip "$update_rpm" | awk '/^Build Date  :/ {print $4, $5, $6, $7}')
    echo "Checking for package: $update_name"
    # Find the corresponding RPM in the SEARCH_DIR
    find "$SEARCH_DIR" -name "${update_name}-*.rpm" | while read original_rpm; do
        # Get the name from the original RPM to verify it's the correct one
        original_name=$(rpm -qip "$original_rpm" | awk '/^Name        :/ {print $3}')
        # Only proceed if the package names match
        if [ "$original_name" == "$update_name" ]; then
            # Get the build date from the original RPM
            original_builddate=$(rpm -qip "$original_rpm" | awk '/^Build Date  :/ {print $4, $5, $6, $7}')
            # Convert the build dates to Unix timestamp for comparison
            update_timestamp=$(date -d "$update_builddate" +%s)
            original_timestamp=$(date -d "$original_builddate" +%s)
            if [ "$update_timestamp" -gt "$original_timestamp" ]; then
                echo -e "\033[1K$original_name update is newer. Replacing $original_rpm\r"; echo "Updated $original_name with $update_rpm" >> $LOG_FILE
                # Copy the newer RPM to the same folder as the original RPM
                cp "$update_rpm" "$(dirname "$original_rpm")"
                # Delete the original older RPM
                #echo "Deleting original: $original_rpm"
                rm -f "$original_rpm"; echo "Deleted $original_rpm" >> $LOG_FILE
            else
                echo "$original_name package is up-to-date or newer."; echo "Found update RPM $update_rpm but existing $original_rpm is same or newer." >> $LOG_FILE
            fi
        fi
    done
done
#Last step, rebuild repos!
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
echo -e "\033[1;32m\\nSee $LOG_FILE for details.\033[0m"
echo -e "\033[1;32m\\nResize completed.  Please rerun the rebuild.sh script from the /root/buildabox directory.\033[0m\n"
