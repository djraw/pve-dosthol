#! /bin/bash

# dosthol - Do something on LAN
#	Skript to do something with remote virtual machines
#	Written primarily for Proxmox VE >=v4.x
#
# Author: Oliver Jaksch <proxmox-forum@com-in.de>
#
# Client changelog:
#	v0.1 (2020-12-02) - Initial release of the dosthol GUI
#
# Distributed under the terms of the GNU General Public License v3 (https://www.gnu.org/licenses/gpl)



# check for missing dependencies
for packages in zenity; do
    checkbin=$(which ${packages} &>/dev/null)
    [[ ${?} = 1 ]] && echo "Missing program ${packages}, can't continue without it. Exiting." && exit 1
done

INIFILE=~/dostholc-gui.ini
ZHEIGHT=$(expr 100 + $(wc -l ${INIFILE} | awk '{print $1}') \* 27)

# https://help.gnome.org/users/zenity/3.24/index.html
MACS=$(zenity \
  --list \
  --title="Choose one or more VMs" \
  --text="List of available VMs:" \
  --width=500 \
  --height=${ZHEIGHT} \
  --checklist \
  --print-column=2,3,4 \
   --column="Action?" --column="VM ID" --column="VM Name" --column="MAC" \
  `while read vmentry; do
    echo "FALSE|${vmentry}" | awk -F "|" '{print $1,$2,$3,$4}'
  done < ${INIFILE}`
)
[[ ${?} = 1 ]] && exit 0
if [ "${MACS}" = "" ]; then
    zenity --error --width=200 --text "No VM(s) selected. Exiting."
    exit 1
fi

CMND=$(zenity \
  --list \
  --title="What action to send to choosen VM(s)" \
  --text="List of available actions:" \
  --width=700 \
  --height=300 \
  --radiolist \
  --print-column=2 \
  --column="" --column="Action" --column="ss" --column="Meaning" \
  --hide-column=3 \
  FALSE wakeup FFFFFFFFFFFF "Start virtual machine." \
  FALSE shutdown EEEEEEEEEEEE "Shutdown virtual machine. This is similar to pressing the power button on a physical machine.This will send an ACPI event for the guest OS, which should then proceed to a clean shutdown." \
  FALSE poweroff DDDDDDDDDDDD "Stop virtual machine. The qemu process will exit immediately. Thisis akin to pulling the power plug of a running computer and may damage the VM data" \
  FALSE suspend CCCCCCCCCCCC "Suspend virtual machine." \
  FALSE resume BBBBBBBBBBBB "Resume virtual machine." \
  FALSE reset AAAAAAAAAAAA "Reset virtual machine (qemu only)." \
  FALSE reboot ABABABABABAB "Reboot the VM by shutting it down, and starting it again. Applies pending changes."
)
[[ ${?} = 1 ]] && exit 0
if [ "${CMND}" = "" ]; then
    zenity --error --width=200 --text "No action selected. Exiting."
    exit 1
fi


BCAST=$(zenity \
  --entry \
  --title="Aand finally the broadcast address" \
  --text="Broadcast on actual subnet - or enter another IP or subnet" \
  --entry-text="255.255.255.255" \
  --height=150
)
[[ ${?} = 1 ]] && exit 0
case "${BCAST}" in
    "") zenity --error --width=200 --text "Broadcast address can't be empty. Exiting."
	 exit 1
	 ;;
      *) if ! [[ "${BCAST}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	   zenity --error --width=200 --text "Broadcast address invalid. Exiting."
	 fi ;;
esac

# https://stackoverflow.com/questions/22354082/print-every-nth-column-of-a-file
SENDVIDS=$(echo $MACS | awk -F "|" '{ for (i=1;i<=NF;i+=3) print $i }')
SENDNAMS=$(echo $MACS | awk -F "|" '{ for (i=2;i<=NF;i+=3) print $i }')
SENDMACS=$(echo $MACS | awk -F "|" '{ for (i=3;i<=NF;i+=3) print $i }')

# zenity --notification --window-icon="info" --text="dosthol is sending (${CMND}) via (${BCAST}) to VM(s):\n${SENDVIDS}"
zenity --notification --window-icon="info" --text="dosthol is sending (${CMND}) via (${BCAST}) to VM(s):\n${SENDNAMS}"
for i in ${SENDMACS}; do
  dostholc.sh -f ${CMND} -m ${i} -i ${BCAST}
done
