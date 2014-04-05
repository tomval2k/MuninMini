#!/bin/sh

graph() {
echo "multigraph ping_packetloss
graph_title Ping Packet Failure Rate
graph_args --base 1000 --lower-limit 0 --upper-limit 100
graph_vlabel Packlet loss (%)
graph_info Ping will send packets until it reaches the required count; but will keep sending for upto x seconds if '-w x' is set and succesful pings do not yet equal the required count.
graph_category Server Monitoring
packetloss.info Packets lost on route back from destination server.
packetloss.label Packet loss (%)"

echo "multigraph ping_timings
graph_title Ping Timings
graph_args --base 1000 --lower-limit 0
graph_vlabel Timings (ms)
graph_info Time taken for packets to return to sending node from destination server.
graph_category Server Monitoring
min.info Time taken for quickest packet to return to node.
avg.info Average time taken for all packets to return to node.
max.info Time taken for slowest packet to return to node.
min.label minimum (ms)
avg.label average (ms)
max.label maximum (ms)"

	if [ "$1" = "data" ]; then data; fi
}

data() {
	PING_SERVER=tomvalentine.net
	PING_COUNT=2
	PING_INITIAL_TIMEOUT=2
	PING_GLOBAL_TIMEOUT=10
	PING_X_OPTIONS="-q"
	PING_COMMAND="ping $PING_SERVER -c $PING_COUNT -W $PING_INITIAL_TIMEOUT -w $PING_GLOBAL_TIMEOUT $PING_X_OPTIONS"
	PING_RESULT=$($PING_COMMAND 2> /dev/null)

	echo "$PING_RESULT" | awk ' /packet loss/ { FS=" |%"; print "multigraph ping_packetloss\npacketloss.value " $7 }'
	echo "$PING_RESULT" | awk ' END { FS=" |/"; print "multigraph ping_timings\nmin.value " $6 " \navg.value " $7 " \nmax.value " $8 }'
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