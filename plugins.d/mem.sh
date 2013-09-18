#!/bin/sh

graph() {
echo "graph_title Memory usage
graph_args --base 1024 --lower-limit 0
graph_vlabel Bytes
graph_category system
graph_info Allocation of memory on the node.
graph_order used free cached buffers shared
total.label Total
used.label Used
used.draw AREA
free.label Free
free.draw STACK
cached.label Cached
cached.draw AREA
buffers.label Buffers
buffers.draw STACK
shared.label Shared
shared.draw STACK
used.info Sum of all allocated memroy (including cached).
free.info Unallocated memory.
cached.info Allocated, but available if needed.
buffers.info Allocated, and in use.
shared.info Allocated, shared between different processes.
total.info Total memory on node."

	if [ "$1" = "data" ]; then data; fi
}

data() {
	awk 'BEGIN {total=0; used=0; free=0; shared=0; buffers=0; cached=0}
	/^Mem:/ {total=$2; used=$3; free=$4; shared=$5; buffers=$6; cached=$7; exit} 
	/^MemTotal:/ {total=$2 * 1024} 
	/^MemFree:/ {free=$2 * 1024} 
	/^MemFree:/ {used=total - free} 
	/^MemShared:/ {shared=$2 * 1024} 
	/^Buffers:/ {buffers=$2 * 1024} 
	/^Cached:/ {cached=$2 * 1024} 
	END { print "total.value " total "\nused.value " used "\nfree.value " free "\nshared.value " shared "\nbuffers.value " buffers "\ncached.value " cached } 
	' < /proc/meminfo
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
