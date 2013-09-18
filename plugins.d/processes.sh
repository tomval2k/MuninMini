#!/bin/sh

graph() {
echo "graph_title Number of Processes
graph_args --base 1000 -l 0
graph_vlabel Count
graph_category processes
graph_info How many processes are currently running on the system.
processes.label processes
processes.info Number of running processes."

	if [ "$1" = "data" ]; then data; fi
}

data() {
	count=0; for i in /proc/[0-9]*; do count=$(( $count + 1 )); done; echo "processes.value $count"
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
