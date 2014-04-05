#!/bin/sh

graph() {
echo "graph_title Load average
graph_args --base 1000 -l 0
graph_vlabel load
graph_scale no
graph_category system
load.label load
load.warning 10
load.critical 120
graph_info The load average of the machine describes how many processes are in the run-queue (scheduled to run 'immediately').
load.info Average load for last five minutes."

	if [ "$1" = "data" ]; then data; fi
}

data() {
	awk '{ print "load.value " $2 }' /proc/loadavg
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