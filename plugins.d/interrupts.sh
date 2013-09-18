#!/bin/sh

graph() {
echo "graph_title Interrupts & context switches
graph_args --base 1000 -l 0
graph_vlabel interrupts & ctx switches / \${graph_period}
graph_category system
graph_info This graph shows the number of interrupts and context switches on the system. These are typically high on a busy system.
intr.info Interrupts are events that alter sequence of instructions executed by a processor. They can come from either hardware (exceptions, NMI, IRQ) or software.
ctx.info A context switch occurs when a multitasking operatings system suspends the currently running process, and starts executing another.
intr.label interrupts
ctx.label context switches
intr.type DERIVE
ctx.type DERIVE
intr.max 100000
ctx.max 100000
intr.min 0
ctx.min 0"

	if [ "$1" = "data" ]; then data; fi
}

data() {
	awk '/^ctxt/ { print "ctx.value " $2 } /^intr/ { print "intr.value " $2 }' < /proc/stat
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
