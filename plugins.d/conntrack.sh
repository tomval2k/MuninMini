#!/bin/sh

# dependencies:
if [ ! -r /proc/net/ip_conntrack ]; then
	echo "# No read access to plugin datasource"; 
	exit 1; 
fi


graph() {
echo "graph_title Conntrack
graph_args --base 1000 -l 0
graph_vlabel Count
graph_category network
graph_info TCP & UDP connections reported by /proc/net/ip_conntrack. State definitions taken from 'man netstat'.
established.label established
time_wait.label time_wait
listen.label listen
syn_sent.label syn_sent
syn_recv.label syn_recv
fin_wait1.label fin_wait1
fin_wait2.label fin_wait2
close.label close
close_wait.label close_wait
closing.label closing
last_ack.label last_ack
udp.label udp
established.info The socket has an established connection.
time_wait.info The socket is waiting after close to handle packets still in the network.
listen.info The socket is listening for incoming connections.
syn_sent.info The socket is actively attempting to establish a connection.
syn_recv.info A connection request has been received from the network.
fin_wait1.info The socket is closed, and the connection is shutting down.
fin_wait2.info Connection is closed, and the socket is waiting for a shutdown from the remote end.
close.info The socket is not being used.
close_wait.info The remote end has shut down, waiting for the socket to close.
closing.info Both sockets are shut down but we still don't have all our data sent.
last_ack.info The remote end has shut down, and the socket is closed. Waiting for acknowledgement.
udp.info UDP sockets"

	if [ "$1" = "data" ]; then data; fi
}

data() {
# whilst awk '{ do stuff }' < /input/file is quicker
# this seemed to produce a shorter ip_conntrack output than using cat
# not sure why, maybe buffering or something...
# hence 'VAR=$(cat /input/file); echo $VAR | awk' instead

CONNTRACK=$(cat /proc/net/ip_conntrack)
echo "$CONNTRACK" | awk 'BEGIN {
ESTABLISHED=0; \
TIME_WAIT=0; \
LISTEN=0; \
SYN_SENT=0; \
SYN_RECV=0; \
FIN_WAIT1=0; \
FIN_WAIT2=0; \
CLOSE=0; \
CLOSE_WAIT=0; \
CLOSING=0; \
LAST_ACK=0; \
UDP=0; \
} \
/^tcp.* ESTABLISHED .*$/ { ESTABLISHED++ } \
/^tcp.* TIME_WAIT .*$/ { TIME_WAIT++ } \
/^tcp.* LISTEN .*$/ { LISTEN++ } \
/^tcp.* SYN_SENT .*$/ { SYN_SENT++ } \
/^tcp.* SYN_RECV .*$/ { SYN_REC++ } \
/^tcp.* FIN_WAIT1 .*$/ { FIN_WAIT1++ } \
/^tcp.* FIN_WAIT2 .*$/ { FIN_WAIT2++ } \
/^tcp.* CLOSE .*$/ { CLOSE++ } \
/^tcp.* CLOSE_WAIT .*$/ { CLOSE_WAIT++ } \
/^tcp.* CLOSING .*$/ { CLOSING++} \
/^tcp.* LAST_ACK .*$/ { LAST_ACK++ } \
/^udp.*$/ { UDP++ } \
END { print \
"established.value " ESTABLISHED\
"\ntime_wait.value " TIME_WAIT\
"\nlisten.value " LISTEN\
"\nsyn_sent.value " SYN_SENT\
"\nsyn_recv.value " SYN_RECV\
"\nfin_wait1.value " FIN_WAIT1\
"\nfin_wait2.value " FIN_WAIT2\
"\nclose.value " CLOSE\
"\nclose_wait.value " CLOSE_WAIT\
"\nclosing.value " CLOSING\
"\nlast_ack.value " LAST_ACK\
"\nudp.value " UDP\
}'

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