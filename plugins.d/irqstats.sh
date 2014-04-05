#!/bin/sh

graph() {
echo "graph_title Individual interrupts
graph_args --base 1000 -l 0
graph_vlabel interrupts
graph_category system"

	awk '/[0-9]+:/ {
	#	i=gensub(/:/, "", "g", $1);
	#	print "i" i ".label " $4 "\ni" i ".info Interrupt " i ", for device(s): " $4 "\ni" i ".min 0\ni" i ".type DERIVE"
		gsub(/:/, "", $1);
		print "i" $1 ".label " $4 "\ni" $1 ".info Interrupt " $1 ", for device(s): " $4 "\ni" $1 ".min 0\ni" $1 ".type DERIVE"
	}
	/ERR:/ {
		print "iERR.label ERR\niERR.type DERIVE\niERR.min 0"
	} ' < /proc/interrupts

	if [ "$1" = "data" ]; then data; fi
}

data() {
	awk '/[0-9]+:/ {
		gsub(/:/, "", $1);
		print "i" $1 ".value " $2
	}
	/ERR:/ {
		print "iERR.value " $2
	}' < /proc/interrupts
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

