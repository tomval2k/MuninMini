#!/bin/sh

graph(){
echo "graph_title Internet Usage
graph_args --base 1000 --lower-limit 0 --upper-limit 20
graph_vlabel Fair Usages Quota (GB)
graph_category bandwidth
graph_info ISP limits network throughtput based on a rolling 30 day period and this is reported on a webpage accessible from the CPE.
quota.label Fair Usage Quota
remaining.label Remaining
quota.info Total data allowed in any given rolling 30 day period.
remaining.info Remaining data available.
booster.label Booster Allowance
booster.info Reflects possible negative allowance from previous limits.
used.label Used
used.info Amount of data downloaded and uploaded in last 30 days."
	if [ "$1" = "data" ]; then data; fi
}

data() {
STATE_FILE="/tmp/munin-quotaCheck.state"

# check if file exists, if so read it unless chance is 3/100
# random number is generated BETWEEN 0 and 1, multiplied by 100, added to 1
# then chopped into an integer, to give a range of 1-100.
# a 4% chance of the file being refreshed every 5 minutes
# 100 times = 8 hours 20 minutes, 4% = every 2 hours 5 minutes (on average)

if [ -w $STATE_FILE ] && [ $(awk 'BEGIN {srand(); print int(rand() * 100 + 1)}') -gt 2 ]; then
	cat $STATE_FILE
else
	TIMEOUT=3
	COOKIE=$(echo -e "HEAD / HTTP/1.0\nHost: portal.avantiplc.com\nCache-Control: max-age=0\n\n" | nc portal.avantiplc.com 80 -w $TIMEOUT 2> /dev/null | awk '/Set-Cookie/ && NR==10 { FS=" |;"; print $2}')
	DATA=$(echo -e "GET / HTTP/1.0\nHost: portal.avantiplc.com\nCookie: $COOKIE\n\n" | nc portal.avantiplc.com 80 -w $TIMEOUT 2> /dev/null)
#	echo "$DATA" > /tmp/quota.data.txt
#	STD_OUT=$(echo "$DATA" | awk '/inclusive/ { print gensub(/.*>([0-9\.]{1,9}) GB.*remaining.*usage of ([0-9\.]{1,9}) GB.*/, "remaining.value \\1\nquota.value \\2", g) } ')
	STD_OUT=$(echo "$DATA" | awk '
		/inclusive/ { print gensub(/.*inclusive usage of ([0-9\.]{1,9}) GB.*/, "quota.value \\1", g)} 
		/total usage/ { print gensub(/.*this month is ([0-9\.]{1,9}) GB.*/, "used.value \\1", g)} 
		/total usage/ { print gensub(/.*>([0-9]{1,3}\.[0-9]{3}) GB \(.*/, "remaining.value \\1", g)}	
		/booster/ { print gensub(/.*>([0-9]{1,3}\.[0-9]{3}) GB \(.*/, "booster.value \\1", g)}
		')
	if [ "$STD_OUT" = "" ]; then
		echo "# ERROR: Response from server was blank, possibly unreachable."
	else
		echo "$STD_OUT" > $STATE_FILE
		echo "$STD_OUT"
	fi	
fi
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