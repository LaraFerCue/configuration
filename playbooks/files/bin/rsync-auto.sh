#!/bin/sh
# shellcheck disable=SC2039,SC2013,SC2068,SC2064,SC2086
# SC2039: local is defined in FreeBSD's shell.
# SC2013: piping/redirecting file into 'while read' loop avoids assigning variables.
# SC2068: parse_arguments expects splitted elements.
# SC2064: the MTREE_FILE must be expanded when the trap is created.
# SC2086: the rsync arguments have to be expanded.

# Gets a mtree of the working directory specified and synchronize with the
# machine given if needed.
PROG_NAME=$(basename "${0}")
WORKING_DIR=
IP_ADDRESS=
REMOTE_USER=
REMOTE_PATH=
USE_VAGRANT=false
EXCLUDE_FILE=

MTREE_FILE=$(mktemp "/tmp/${PROG_NAME}_mtree.XXXXXXXX")
RSYNC_ARGS="
--recursive
--links
--times
--devices
--specials
--verbose
"

usage()
{
	cat << USAGE
${PROG_NAME} [options]
	--working-dir <directory>	Specifies the directory to sync.
	--machine <ip-address>		IP address of the machine to use as target.
	--vagrant			Use the command 'vagrant rsync' to sync.
	--exclude-file <file>		File used to set the excludes for rsync.
	--remote-user <username>	User to use in the remote machine.
	--remote-path <path>		Path in the remote machine. Default <working-dir>.

NOTES:
	The options '--machine' and '--vagrant' cannot be given at the same time.
USAGE
}

print_error()
{
	local msg=${1}

	echo "${PROG_NAME}: ${msg}" >&2
	usage >&2

	exit 1
}

check_arguments()
{
	if [ -z "${WORKING_DIR}" ] ; then
		print_error "--working-dir is mandatory"
	fi

	if ${USE_VAGRANT} && [ "${IP_ADDRESS}" ] ; then
		print_error "--vagrant and --machine cannot be given at the same time"
	fi
	
	if ! ${USE_VAGRANT} && [ -z "${IP_ADDRESS}" ] ; then
		print_error "either --vagrant or --machine must be given"
	fi

	if [ -z "${REMOTE_PATH}" ] ; then
		REMOTE_PATH="${WORKING_DIR}"
	fi
}

parse_arguments()
{
	local argument option

	while [ "${1}" ] ; do
		argument="${1}"
		shift

		case "${argument}" in
			--vagrant)
				USE_VAGRANT=true
				;;
			--working-dir)
				option="${1}"
				shift

				if [ -d "${option}" ] ; then
					WORKING_DIR="${option}"
				fi
				;;
			--machine)
				option="${1}"
				shift

				if ping -c 2 "${option}" > /dev/null 2>/dev/null ; then
					IP_ADDRESS="${option}"
				fi
				;;
			--exclude-file)
				option="${1}"
				shift

				if [ -r "${option}" ] ; then
					EXCLUDE_FILE="${option}"
				else
					print_error "exclude-file ${option} is not readable"
				fi
				;;
			--remote-user)
				option="${1}"
				shift

				REMOTE_USER="${option}"
				;;
		esac
	done
}

create_mtree()
{
	local exclude_args
	local working_dir=${1}
	local mtree_file=${2}
	local exclude_file=${3:-}

	if [ -r "${exclude_file}" ] ; then
		exclude_args="-X ${exclude_file}"
	else
		exclude_args=
	fi

	mtree -c -k 'mode,link,sha256,size,type' -p "${working_dir}" ${exclude_args} > "${mtree_file}"
}

check_mtree()
{
	local exclude_args
	local working_dir=${1}
	local mtree_file=${2}
	local exclude_file=${3:-}

	if [ -r "${exclude_file}" ] ; then
		exclude_args="-X ${exclude_file}"
	else
		exclude_args=
	fi

	mtree -f "${mtree_file}" -k 'mode,link,sha256,size,type' -p "${working_dir}" ${exclude_args} \
		> /dev/null 2>/dev/null
}

rsync_to_machine()
{
	local working_dir=${1}
	local ip_address=${2}
	local remote_path=${3}
	local username=${4:-}
	local exclude_file=${5:-}
	local rsync_args

	rsync_args="${RSYNC_ARGS}"
	if [ -r "${exclude_file}" ] ; then
		rsync_args="${rsync_args} --exclude-from=${exclude_file}"
	fi
	rsync ${rsync_args} "${working_dir}" "${username}@${ip_address}:${remote_path}"
}

use_command_with_date()
{
	local date output

	date=$(date '+%H:%M:%S')

	${@} | while read -r output ; do
		echo "${date} | ${output}"
	done
}

parse_arguments ${@}
check_arguments

trap "trap '' INT QUIT; rm ${MTREE_FILE}; exit 0" INT QUIT
while true; do
	if ! [ -s "${MTREE_FILE}" ] || \
		! check_mtree "${WORKING_DIR}" "${MTREE_FILE}" "${EXCLUDE_FILE}"
	then
		if "${USE_VAGRANT}" ; then
			use_command_with_date vagrant rsync
		else
			use_command_with_date rsync_to_machine \
				"${WORKING_DIR}" \
				"${IP_ADDRESS}" \
				"${REMOTE_PATH}" \
				"${REMOTE_USER}" \
				"${EXCLUDE_FILE}"
		fi
	fi
	create_mtree "${WORKING_DIR}" "${MTREE_FILE}" "${EXCLUDE_FILE}"
done

