#!/bin/sh

graph() {
# script runs much quicker if have one multiline 'echo' rather than several,
# but for readability in this plugin have maintained several 'echo' commands

# http://munin-monitoring.org/wiki/HowToWritePlugins
# http://munin-monitoring.org/wiki/graph_args
	echo "graph_title Random"
	echo "graph_args --base 1000 --lower-limit 0 --upper-limit 10"		#base of 1000 used when scaling, lowest value of graph is 0
	echo "graph_vlabel Random Number"
#	echo "graph_category other"
#	long explanation at bottom of graphs
	echo "graph_info A sort-of random number generated each time munin asks for data, just to draw a changeable graph."
# list of data fields and the type/warn/critical/info values for each field (displayed in a table below the graphs)
	echo "random.label random"
#	echo "random.warning 9"
#	echo "random.critical 9.5"
	echo "random.info A random value."

# enable support for dirtyconfig
	if [ "$1" = "data" ]; then data; fi
}

data() {
# generate a random number from 0 to 10 to 1 decimal place
# awk rand() is between 0 and 1, so will be between 0 and 10, also the seed is based on seconds of time (not milliseconds)
# first method is not truly random but sufficient to generate the test graph that I want
# second method is a lot more random, but when router was under heavy load seemed to just hang
##	VALUE=$(cat /proc/uptime | md5sum | sed -e 's/[- a-z]//g' -e 's/\([0-9]\)\([0-9]\).*/\1.\2/')
#	VALUE=$(cat /dev/urandom | tr -cds '0123456789' | head -c 1)
	VALUE=$(awk 'BEGIN { srand();  print int(rand() * 100) / 10; exit }')
	echo "random.value $VALUE"
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