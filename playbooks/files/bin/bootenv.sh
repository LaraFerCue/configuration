#!/bin/sh

# Handles a boot environment using ZFS on an encrypted disk, which needs a
# separate ZFS pool to boot.
#
# Main problem is that the boot pool is used to boot the kernel, and then
# boot into the boot environment.

usage() {
	cat > /dev/stderr <<USAGE
$(basename "${0}") boot_environment kernel

boot_environment:	the created boot environment requested
			for activation
kernel:			The kernel to be used with the boot
			environment.
USAGE
}

boot_environment=
kernel=

while [ "${1}" ] ; do
	if [ "${1}" = "-h" ] || [ "${1}" = "--help" ] ; then
		usage
		exit 0
	elif [ -z "${boot_environment}" ] ; then
		boot_environment="${1}"
	else
		kernel="${1}"
	fi
	shift
done

if [ -z "${boot_environment}" ] || [ -z "${kernel}" ] ; then
	usage
	exit 1
fi

sudo sed -i '.bak' 's/^kernel=.*$//g' /boot/loader.conf
sudo echo "kernel=\"${kernel}\"" >> /boot/loader.conf

sudo beadm activate "${boot_environment}"
