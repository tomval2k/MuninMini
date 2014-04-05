#!/bin/sh

graph() {
echo "graph_title CPU usage
graph_order system user nice idle
graph_args --base 1000 -r --lower-limit 0
graph_vlabel %
graph_info This graph shows how CPU time is spent.
graph_category system
graph_period second
system.label system
system.draw AREA
system.max 5000
system.min 0
system.type DERIVE
system.info CPU time spent by the kernel in system activities
user.label user
user.draw STACK
user.min 0
user.max 5000
user.type DERIVE
user.info CPU time spent by normal programs and daemons
nice.label nice
nice.draw STACK
nice.min 0
nice.max 5000
nice.type DERIVE
nice.info CPU time spent by nice(1)d programs
idle.label idle
idle.draw STACK
idle.min 0
idle.max 5000
idle.type DERIVE
idle.info Idle CPU time"

	if [ "$1" = "data" ]; then data; fi
}

data() {
	awk '/^cpu / { print "user.value " $2 "\nnice.value " $3 "\nsystem.value " $4 "\nidle.value " $5; exit }' < /proc/stat
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