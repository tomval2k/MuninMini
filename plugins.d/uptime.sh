#!/bin/sh

graph() {
echo "graph_title Uptime
graph_args --base 1000 -l 0
graph_vlabel Uptime (days)
graph_category system
graph_info Length of time system has been running.
uptime.info Length of time system has been running.
uptime.label Uptime
uptime.draw AREA
uptime.cdef uptime,86400,/"

	if [ "$1" = "data" ]; then data; fi
}

data() {
	while read line; do var=${line% *}; echo "uptime.value $var"; done < /proc/uptime
}

case "$1" in
	graph)
		graph $2
	;;
	data)
		data
	;;
	*)
		echo "# You should panic. Or affix either 'graph' or 'data' to the command you called this script with."
		echo "# e.g. $0 data"
	;;
esac
exit 0