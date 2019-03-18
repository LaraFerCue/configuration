#!/bin/sh -eu

LOCAL_REV=${1}
REMOTE_REV=${2}
URL=${3}
SRC_PATH=${4:-/usr/src}

DIFF_FILE=$(mktemp /tmp/system-builder.XXXXXX)
svn diff --summarize --revision "${LOCAL_REV}:${REMOTE_REV}" \
	"${URL}" > "${DIFF_FILE}"
svn "${SRC_PATH}"

TARGETS=
if grep -qE '^[^[:space:]]+[[:space:]]sys/' "${DIFF_FILE}" ; then
	TARGETS="${TARGETS} buildkernel"
fi

if grep -qvE '^[^[:space:]]+[[:space:]]sys/' "${DIFF_FILE}" ; then
	TARGETS="${TARGETS} buildworld"
fi

for target in ${TARGETS} ; do
	touch "/var/run/system-builder.${target}"
	cd "${SRC_PATH}" && make "${target}"
	rm "/var/run/system-builder.${target}"
done

touch "/var/run/system-builder.ready"
