#!/bin/sh

graph() {
echo "graph_title Arp Cache
graph_args --base 1000
graph_vlabel Count
graph_category network
graph_info Arp count for devices on all interfaces.
arp.label arp count"

	if [ "$1" = "data" ]; then data; fi
}

data() {
#	ARP=$(($(cat /proc/net/arp | wc -l) - 1))
#	echo arp.value $ARP
	awk 'END { print "arp.value " NR -1 }' < /proc/net/arp
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