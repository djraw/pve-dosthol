#!/bin/bash

# dosthol - Do something on LAN
#	Skript to do something with remote virtual machines
#	Written primarily for Proxmox VE >=v4.x
#
# Author: Oliver Jaksch <proxmox-forum@com-in.de>
#
# Client changelog:
#	v0.7 (2020-12-02) - Fixup dependency check, added Reboot command, changed from GPLv2 to GPLv3
#	v0.6 (2020-12-02) - Check for missing dependencies
#	v0.5 - nothing changed
#	v0.4 - nothing changed
#	v0.3 (2016-03-11) - Parameter parsing, help extended, some beautifyings
#	v0.2 (2016-03-07) - Renamed dosthol to dosthold, created client dostholc, finished more commands, turned to socat
#	v0.1 (2016-03-06) - Initial work; starting virtual machines per wake-on-lan works
#
# Distributed under the terms of the GNU General Public License v3 (https://www.gnu.org/licenses/gpl)



function HELP {
echo "
 dostholc - The dosthol client, v0.7
 Call it with at least two parameters, like 'dostholc -f FUNCTION -m MAC'
 Possible parameters are
 -f | --function	(one of wakeup|shutdown|poweroff|suspend|resume|reboot|reset (n/a for lxc))
 -m | --mac		(MAC address in the form of 11:22:33:44:55:66)
 -v | --verbose		(0 for no output (default), 1 for some output)
 -i | --ip		(255.255.255.255 (default) for broadcast on actual subnet - or enter another IP or subnet)

 ${1}
  "
  exit
}

# check for missing dependencies
for packages in socat xxd; do
    checkbin=$(which ${packages} &>/dev/null)
    [[ ${?} = 1 ]] && echo "Missing program ${packages}, can't continue without it. Exiting." && exit 1
done

# parse parameters
while [[ ${#} > 1 ]]
do
PARAM="${1}"

case ${PARAM} in
    -f|--function)	FUNC="${2}" ; shift ;;
    -m|--mac)		MAC="${2}" ; shift ;;
    -v|--verbose)	VERB="${2}" ; shift ;;
    -i|--ip)		IPADDR="${2}" ; shift ;;
    *)			HELP ;;
esac
shift
done

case "${FUNC}" in
    wakeup)	HEADER="FFFFFFFFFFFF" ;;
    shutdown)	HEADER="EEEEEEEEEEEE" ;;
    poweroff)	HEADER="DDDDDDDDDDDD" ;;
    suspend)	HEADER="CCCCCCCCCCCC" ;;
    resume)	HEADER="BBBBBBBBBBBB" ;;
    reset)	HEADER="AAAAAAAAAAAA" ;;
    reboot)	HEADER="ABABABABABAB" ;;
    *)		HELP "- FUNCTION invalid or missing -" ;;
esac

# check for valid MAC
# bash foo thanks to <https://stackoverflow.com/questions/19959537/bash-regex-match-mac-address>
[[ "${MAC}" =~ ^([a-fA-F0-9]{2}:){5}[a-zA-Z0-9]{2}$ ]] || HELP "- MAC address invalid or missing -"

# check for valid IP
# bash foo thanks to <https://www.linuxjournal.com/content/validating-ip-address-bash-script>
[[ "${IPADDR}" = "" ]] && IPADDR="255.255.255.255"
[[ "${IPADDR}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || HELP "- IP address invalid -"

[[ "${VERB}" = "1" ]] && echo "Broadcasting command '${FUNC}' with MAC '${MAC}' to IP/subnet '${IPADDR}'"

# build 16 blocks of MAC
for REP in {1..16}; do
    FMAC+=`echo ${MAC} | tr -d ":"`
done

# send MagicPacket, could'nt got it to work with gnu-netcat nor openbsd-netcat
# socat witchcraft thanks to <http://hustoknow.blogspot.de/2011/11/setting-up-wake-on-lan-in-your-own-home.html>
echo -n "${HEADER}${FMAC}" | xxd -r -u -p | socat - UDP-DATAGRAM:255.255.255.255:9,broadcast
