#!/bin/sh
# shellcheck disable=SC2039,SC2155

STOPPED=false
ETH_NIC='em0'

TEMP_WARN="60"
TEMP_CRIT="70"

_stop()
{
	STOPPED=true
}

_continue()
{
	STOPPED=false
}

ipv6()
{
	local ipv6=$(ifconfig "${ETH_NIC}" | \
		grep 'inet6' | awk '{ print $2 "/" $4 }')
	if [ "${ipv6}" ] ; then
		echo -n "{\"name\":\"ipv6\",\"color\":\"#00FF00\",\"full_text\":\"IPv6: ${ipv6}\"}"
	else
		echo -n "{\"name\":\"ipv6\",\"color\":\"#FF0000\",\"full_text\":\"No IPv6\"}"
	fi
}

zfs_disk()
{
	local zpool_space=$(zpool list -H zroot | awk '{ print $4 "/" $2 }')
	local color

	if zpool status -x | grep -q "all pools are healthy" ; then
		color="#00FF00"
	else
		color="#FF0000"
	fi
	echo -n "{\"name\":\"zfs_disk\",\"color\":\"${color}\",\"full_text\":\"${zpool_space}\"}"
}

wlan()
{
	# Do it on the laptop
	echo -n "{\"name\":\"wlan\",\"color\":\"#FF0000\",\"full_text\":\"W: down\"}"
}

ipv4()
{
	local ipv4=$(ifconfig "${ETH_NIC}" | \
		grep -E '[[:space:]]inet[[:space:]]' | awk '{ print $2}')
	local mask=$(ifconfig "${ETH_NIC}" | \
		grep -E '[[:space:]]inet[[:space:]]' | awk '{ print $4}')
	local bits=0

	mask=$(printf "%d" "${mask}")
	while [ "${mask}" -gt 0 ] ; do
		if [ "$((mask % 2))" -eq 1 ]; then
			: $((bits += 1))
		fi
		: $((mask /= 2))
	done
	if [ "${ipv4}" ] ; then
		echo -n "{\"name\":\"ipv4\",\"color\":\"#00FF00\",\"full_text\":\"E: ${ipv4}/${bits}\"}"
	else
		echo -n "{\"name\":\"ipv4\",\"color\":\"#FF0000\",\"full_text\":\"E: down\"}"
	fi
}

battery()
{
	# Do it on the laptop
	echo -n "{\"name\":\"battery\",\"full_text\":\"B: none\"}"
}

temp()
{
	local cpu_temp=$(sysctl -n dev.cpu.0.temperature)
	local color

	if [ "${cpu_temp%%.*}" -gt "${TEMP_CRIT}" ] ;then
		color="#FF0000"
	elif [ "${cpu_temp%%.*}" -gt "${TEMP_WARN}" ] ; then
		color="#FFFF00"
	else
		color="#00FF00"
	fi
	echo -n "{\"name\":\"temp\",\"color\":\"${color}\",\"full_text\":\"${cpu_temp}\"}"
}

cpu_load()
{
	local load=$(vmstat -P | awk '
	BEGIN{
		skip = 2
		CPU = 0
	} {
		if (skip==0) {
			for (i=17; i<=NF; i+=3) {
				printf "%s: %d/%d/%d ", CPU, $i, $(i+1), $(i+2)
				CPU = CPU + 1
			}
			print " "
		}
		skip = skip -1
	}')
	echo -n "{\"name\":\"cpu\",\"full_text\":\"CPU ${load}\"}"
}

time_berlin()
{
	local _time=$(env TZ="Europe/Berlin" date '+%H:%M')
	echo -n "{\"name\":\"time\",\"full_text\":\"${_time}\"}"
}

date_time_locale()
{
	local date=$(date '+%d.%m.%Y %H:%M')
	echo -n "{\"name\":\"locale_date\",\"full_text\":\"${date}\"}"
}

_uptime()
{
	local up_time=$(uptime | awk '{ print $3 " " $4}' | sed 's/,.*//')
	echo -n "{\"name\":\"uptime\",\"full_text\":\"Uptime: ${up_time}\"}"
}

trap _stop STOP
trap _cont CONT

echo '{"version":1}'
echo '['
while true ; do
	if ! ${STOPPED} ; then
		printf "[%s,%s,%s,%s,%s,%s,%s,%s,%s,%s],\n" \
			"$(_uptime)" \
			"$(ipv6)" \
			"$(ipv4)" \
			"$(wlan)" \
			"$(zfs_disk)" \
			"$(battery)" \
			"$(temp)" \
			"$(cpu_load)" \
			"$(date_time_locale)" \
			"$(time_berlin)"
	fi
	sleep 5
done
cho ']'
