# pve-dosthol
WakeOnLAN (WOL) and more for ProxmoxVE w/o Python

See: https://forum.proxmox.com/threads/update-wake-and-other-on-lan-for-vms-v0-3.26381/

1. Install daemon dependencies: $ apt install gawk socat xxd
2. Copy dosthold.sh to /usr/local/bin
3. Copy dosthol.service to /etc/systemd/system
4. Start (and enable) the service: $ systemctl enable|start dosthol.service

Then send a MagicPacket/MAC of a VM which can be a qemu or lxc one. The VM should start then.
