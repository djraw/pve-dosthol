#!/bin/bash

# dosthol - Do something on LAN
#	Skript to do something with remote virtual machines
#	Written primarily for Proxmox VE >=v4.x
#
# Author: Oliver Jaksch <proxmox-forum@com-in.de>
#
# Daemon changelog:
#	v0.7 (2020-12-02) - Fixup dependency check, added Reboot command, changed from GPLv2 to GPLv3
#	v0.6 (2020-12-02) - Check for missing dependencies
#	v0.5 (2019-03-17) - Beautify shell execs, limit grep to find only one result (thanks cheffe)
#	v0.4 (2017-01-03) - Expanded Resume: Send a key before resume (Windows Standby)
#	v0.3 (2016-03-11) - Fixed typo in dosthol.service
#	v0.2 (2016-03-07) - Renamed dosthol to dosthold, created client dostholc, finished more commands, turned to socat
#	v0.1 (2016-03-06) - Initial work; starting virtual machines per wake-on-lan works
#
# Distributed under the terms of the GNU General Public License v3 (https://www.gnu.org/licenses/gpl)



function LOG {
    logger -i "dosthol: ${CMDONLAN} VM ${VMID} (${VMNAME}) (${WHICHVIRT})"
}

# check for missing dependencies
for packages in gawk socat xxd; do
    checkbin=$(which ${packages} &>/dev/null)
    [[ ${?} = 1 ]] && echo "Missing program ${packages}, can't continue without it. Exiting." && exit 1
done

while PID=$(pidof -x dosthold.sh); do
FNAM=$(mktemp)

# socat listens on udp/9, when packet arrives it exits
# gawk magic thanks to <https://stackoverflow.com/questions/31341924/sed-awk-insert-commas-every-nth-character>
socat -u udp-recv:9,readbytes=102 - | xxd -u -p -c 102 | gawk '{$1=$1}1' FPAT='.{2}' OFS=: > ${FNAM}

# get header (6*FF / 6*EE)
WOLHEADER=$(cut -b 1-17 ${FNAM})

# valid header?
case "${WOLHEADER}" in
    "FF:FF:FF:FF:FF:FF")	CMDONLAN="start" ;;
    "EE:EE:EE:EE:EE:EE")	CMDONLAN="shutdown" ;;
    "DD:DD:DD:DD:DD:DD")	CMDONLAN="stop" ;;
    "CC:CC:CC:CC:CC:CC")	CMDONLAN="suspend" ;;
    "BB:BB:BB:BB:BB:BB")	CMDONLAN="resume" ;;
    "AA:AA:AA:AA:AA:AA")	CMDONLAN="reset" ;;
    "AB:AB:AB:AB:AB:AB")	CMDONLAN="reboot" ;;
esac

if ! [ "${CMDONLAN=}" = "" ]; then
    # 16*MAC
    WOLMAC=$(cut -b 19- ${FNAM})

    # MAC we're searching for
    MAC=$(cut -b 19-35 ${FNAM})

    # 16*identical MAC = MagicPacket ?
    if [ $(echo ${WOLMAC} | grep -o ${MAC} | wc -l) = 16 ]; then

	# search pve for MAC addresses
	# gawk magic thanks to <https://stackoverflow.com/questions/245916/best-way-to-extract-mac-address-from-ifconfigs-output>
	PVEMACS=`grep -r "net[0-9]:" /etc/pve/local/ | grep -ioE "([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}" | grep -io -m1 "${MAC}"`

	# matching MAC?
	if [ "${PVEMACS}" = "${MAC}" ]; then
	    WHICHVIRT=$(grep -r -m1 "net[0-9]:" /etc/pve/local/ | grep -i "${MAC}" | awk -F '/' '{print $5}')
	    WHICHVMID=$(grep -r -m1 "net[0-9]:" /etc/pve/local/ | grep -i "${MAC}" | awk -F '[/:]' '{print $6}')
	    VMFILE=$(find /etc/pve/local/ -name ${WHICHVMID})
	    VMNAME=$(grep -m1 "name: " ${VMFILE} | awk {'print $2'})
	    VMID=$(echo ${WHICHVMID%.conf})
	    if [ "${WHICHVIRT}" = "qemu-server" ]; then
		LOG
		qm sendkey ${VMID} ctrl-alt &
		qm ${CMDONLAN} ${VMID} &
	    fi
	    if [ "${WHICHVIRT}" = "lxc" ] && ! [ "${CMDONLAN}" = "reset" ]; then
		LOG
		pct ${CMDONLAN} ${VMID} &
	    fi
	fi
    fi
fi

# remove obsolete/invalid socat file
rm ${FNAM}
done
