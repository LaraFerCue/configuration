#!/bin/sh

MAILTO=
LOG_FILE=/dev/stderr

while [ "${1}" ] ; do
	VARIABLE=$(echo "${1}" | awk -F '=' '{ print $1; }')
	VALUE=$(echo "${1}" | awk -F '=' '{ print $2; }')

	case "${VARIABLE}" in
		mailto)
			MAILTO=${VALUE}
			;;
		log-file)
			LOG_FILE=${VALUE}
			;;
		*)
			echo "unknown option" >> "${LOG_FILE}"
			;;
	esac
	shift
done

if [ -z "${MAILTO}" ] ; then
	echo "[error]: no parameter mailto set"
	exit 1
fi

if [ "$(whoami)" != "root" ] ; then
	mail -s "wrong user" "${MAILTO}" << MAIL
The user $(whoami) has not enough permissions to check for pkg updates
for the system. Please be sure to run this command as root.
MAIL
	exit 1
fi

if ! pkg upgrade -n >> "${LOG_FILE}" 2>> "${LOG_FILE}" ; then
	pkg upgrade -n | mail -s "pkg upgrade" "${MAILTO}"
else
	echo "Nothing to do." >> "${LOG_FILE}"
fi
