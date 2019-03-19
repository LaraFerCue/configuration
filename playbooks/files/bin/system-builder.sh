#!/bin/sh -eu

get_svn_info()
{
	local path=${1}
	local param=${2}
	svnlite info "${path}" | grep -E "^${param}:" | \
		sed "s,^${param}: ,,"
}

SRC_PATH=${1:-/usr/src}
LOCAL_REV=$(get_svn_info "${SRC_PATH}" "Last Changed Rev")
URL=$(get_svn_info "${SRC_PATH}" "URL")
REMOTE_REV=$(get_svn_info "${URL}" "Last Changed Rev")

DIFF_FILE=$(mktemp /tmp/system-builder.XXXXXX)
svn diff --summarize --revision "${LOCAL_REV}:${REMOTE_REV}" \
	"${URL}" > "${DIFF_FILE}"

echo "${LOCAL_REV}" > /var/log/system-builder
if [ "$(find /var/run -name 'system-builder.*')" ] ; then
	exit 0
fi

svn up "${SRC_PATH}"

REGEX="^[^[:space:]]+[[:space:]]+${URL}/sys/"
TARGETS=
if grep -qE "${REGEX}" "${DIFF_FILE}" ; then
	TARGETS="${TARGETS} buildkernel"
fi

if grep -qvE "${REGEX}" "${DIFF_FILE}" ; then
	TARGETS="${TARGETS} buildworld"
fi

if [ -z "${TARGETS}" ] ; then
	exit 0
fi

for target in ${TARGETS} ; do
	echo "${LOCAL_REV} -> ${REMOTE_REV}" > "/var/run/system-builder.${target}"
	cd "${SRC_PATH}" && make "${target} -DNO_CLEAN"
	rm "/var/run/system-builder.${target}"
done

cat > "/var/run/system-builder.ready" <<READY
# ${LOCAL_REV} -> ${REMOTE_REV}

for target in ${TARGETS} ; do
	make install\${target##build}
	if [ "\${target}" = "buildkernel" ] ; then
		mergemaster -iF
	fi
done
READY
