#!/bin/sh
# need to disable this plugin on non nvram systems
if [ ! -x /bin/nvram ]
then
	echo "#bw_multi: /bin/nvram not found"
	exit
fi

graph() {
# tomato/rstats uses 1024, so maintaining that convention to ensure consistency
	SCALE=1024
	G_TITLE="rstats Bandwidth Monitoring"
	G_LABEL="Kilobytes"
	G_INFO="rstats is a daemon running on Tomato logging internet data. This plugin retrieves the current total (via httpd)."
	G_CATEGORY="bandwidth"

# bw_daily
echo "multigraph bw_daily
graph_title $G_TITLE [Daily]
graph_args --base $SCALE --lower-limit 0
graph_vlabel $G_LABEL
graph_info $G_INFO
graph_category $G_CATEGORY
graph_order daily_in daily_out
daily_in.info Downloaded data.
daily_out.info Uploaded data.
daily_in.label Incoming
daily_out.label Outgoing
daily_in.cdef daily_in,$SCALE,*
daily_out.cdef daily_out,$SCALE,*
daily_in.draw AREA
daily_out.draw STACK"

#bw_monthly
echo "multigraph bw_monthly
graph_title $G_TITLE [Monthly]
graph_args --base $SCALE --lower-limit 0
graph_vlabel $G_LABEL
graph_info $G_INFO
graph_category $G_CATEGORY
graph_order monthly_in monthly_out
monthly_in.info Downloaded data.
monthly_out.info Uploaded data.
monthly_in.label Incoming
monthly_out.label Outgoing
monthly_in.cdef monthly_in,$SCALE,*
monthly_out.cdef monthly_out,$SCALE,*
monthly_in.draw AREA
monthly_out.draw STACK"

#	echo "monthly_in.graph no"
#	echo "monthly_out.negative monthly_in"

	if [ "$1" = "data" ]; then data; fi
}

data() {
	HTTP_USER=root
	HTTP_PASS=$(nvram get http_passwd)
	HTTP_SERV=$(nvram get lan_ipaddr)
	HTTP_PORT=$(nvram get http_lanport)
	HEX=$(wget http://$HTTP_USER:$HTTP_PASS@$HTTP_SERV:$HTTP_PORT/bwm-daily.asp -q -O - | grep 0x)

echo "multigraph bw_daily"
	HEX_DAILY=$(echo "$HEX" | head -1)
	HEX_DAILY_LATEST=$(echo $HEX_DAILY | sed -e 's/\],/\n/g' -e 's/\[//g' -e 's/\]\];//' -e 's/,/ /g' | tail -1)
	DEC_DAILY_LATEST_IN=$(echo $HEX_DAILY_LATEST | awk 'BEGIN {FS=" "}; {system("echo $((" $2 "))")}')
	DEC_DAILY_LATEST_OUT=$(echo $HEX_DAILY_LATEST | awk 'BEGIN {FS=" "}; {system("echo $((" $3 "))")}')
	echo daily_in.value $DEC_DAILY_LATEST_IN
	echo daily_out.value $DEC_DAILY_LATEST_OUT

echo "multigraph bw_monthly"
	HEX_MONTHLY=$(echo "$HEX" | tail -2 | head -1)
	HEX_MONTHLY_LATEST=$(echo $HEX_MONTHLY | sed -e 's/\],/\n/g' -e 's/\[//g' -e 's/\]\];//' -e 's/,/ /g' | tail -1)
	DEC_MONTHLY_LATEST_IN=$(echo $HEX_MONTHLY_LATEST | awk 'BEGIN {FS=" "}; {system("echo $((" $2 "))")}')
	DEC_MONTHLY_LATEST_OUT=$(echo $HEX_MONTHLY_LATEST | awk 'BEGIN {FS=" "}; {system("echo $((" $3 "))")}')
	echo monthly_in.value $DEC_MONTHLY_LATEST_IN
	echo monthly_out.value $DEC_MONTHLY_LATEST_OUT
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