#!/bin/sh

graph() {
# for each interface reported, draw one traffic graph and one error graph

	sed -e 's/:/ /' -e 's/-/_/' < /proc/net/dev | awk 'NR>2 {
		print "multigraph if_" $1
		print "graph_title " $1 " traffic"
		print "graph_args --base 1024 --lower-limit 0"
		print "graph_vlabel bits in (-) / out (+) per second"
		print "graph_info Traffic through " $1 " interface."
		print "graph_category network_if"
		print "graph_order receive transmit"

		print "receive.label receive"
		print "receive.type DERIVE"
		print "receive.min 0"
		print "receive.graph no"
		print "receive.cdef receive,8,*"

		print "transmit.label transmit"
		print "transmit.type DERIVE"
		print "transmit.min 0"
		print "transmit.cdef transmit,8,*"
		print "transmit.negative receive"
		print "transmit.info Traffic through " $1 " interface."


		print "multigraph if_err_" $1;
		print "graph_title " $1 " errors"
		print "graph_args --base 1000 --lower-limit 0"
		print "graph_vlabel packets in (-) / out (+) per second"
		print "graph_category network_if"
		print "graph_info Errors through " $1 " interface."
		print "graph_order error_receive error_transmit"
		
		print "error_receive.label error_receive"
		print "error_receive.info error some info"
		print "error_receive.type COUNTER"
		print "error_receive.graph no"

		print "error_transmit.label error_transmit"
		print "error_transmit.info error some info"
		print "error_transmit.type COUNTER"
		print "error_transmit.negative error_receive"
		
	} ' 

	if [ "$1" = "data" ]; then data; fi
}

data() {

sed -e 's/:/ /' -e 's/-/_/' < /proc/net/dev | awk ' NR>2 { print "multigraph if_" $1; print "receive.value " $2; print "transmit.value " $10}
NR>2 { print "multigraph if_err_" $1; print "error_receive.value " $4; print "error_transmit.value " $12}'

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
