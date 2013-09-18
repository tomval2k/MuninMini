#!/bin/sh

VERSION="0.9.5-Alpha"
NODENAME="$(cat /proc/sys/kernel/hostname).$(cat /proc/sys/kernel/domainname)"

#note: plugin files must be executable
PLUGIN_DIR="$0plugins.d/"
#may need root for /var/log/*
#LOGFILE="/var/log/MuninMini.log"
LOGFILE="/tmp/MuninMini.log"

#if necessary, truncate log file
if [ -w $LOGFILE ]; then
	LOG_COUNT=$(wc -l < $LOGFILE)
	if [ $LOG_COUNT -gt 150 ]; then
		cat $LOGFILE | awk ' { if (NR > 100) print}' > $LOGFILE
	fi
	#cat /dev/null > $LOGFILE
else
	touch $LOGFILE 2> /dev/null
fi
#check logfile is writable here so that when logging to it, doesn't have to be checked each time causing spurious error output
if [ -w $LOGFILE ]; then
	LOG_WRITABLE=1
fi

#for TRUE, use 1. for FALSE, use 0
USE_QUICK_LIST=0
#these can be changed by the requesting munin server via the 'cap' command
USE_MULTIGRAPH=0
USE_DIRTYCONFIG=0

#round the current time to previous whole 5 minutes, e.g. 12:34 -> 12:30
EPOCH=$(expr $(date -u +%s) / 300 \* 300)

#scanning the plugin directory takes a small amount of time.
#A pre-populated list is quicker, but will not update with changes.
getPluginsQuick() {
	PLUGIN_LIST="conntrack cpu interrupts irqstats load mem netstat processes quotaCheck uptime"
	PLUGIN_LIST_MULTI="bw_multi conntrack cpu interrupts irqstats load mem netstat ping_multi processes quotaCheck uptime"
	PLUGIN_LIST_FINAL=

	if [ $USE_MULTIGRAPH = 0 ]; then
		PLUGIN_LIST_FINAL=$PLUGIN_LIST
	else
		PLUGIN_LIST_FINAL=$PLUGIN_LIST_MULTI
	fi
	echo $PLUGIN_LIST_FINAL
}
getPlugins() {
	PLUGIN_LIST=
	PLUGIN_LIST_X=
	PLUGIN_LIST_FINAL=

	if [ $USE_MULTIGRAPH = 0 ]; then
		PLUGIN_LIST=$(ls -l $PLUGIN_DIR| awk '/.sh$/ && !/multi.sh$/ { n=gensub(/.sh$/, "", "g", $9); printf n " "} ')
	else
		PLUGIN_LIST=$(ls -l $PLUGIN_DIR| awk '/.sh$/ { n=gensub(/.sh$/, "", "g", $9); printf n " "} ')
	fi

#check if each plugin found is executable, time consuming
#removed as will just error (kinda nicely) if the plugin isn't
#	for i in $PLUGIN_LIST
#	do
#		if [ -x "$PLUGIN_DIR$i.sh" ]; then
#			PLUGIN_LIST_X="$i $PLUGIN_LIST_X"
#		fi
#	done
#	PLUGIN_LIST_FINAL=$PLUGIN_LIST_X

	PLUGIN_LIST_FINAL=$PLUGIN_LIST
	echo $PLUGIN_LIST_FINAL
}

getConfig() {
	if [ -x "$PLUGIN_DIR$arg1.sh" ]; then
		if [ $USE_DIRTYCONFIG = 1 ]; then
			A=$($PLUGIN_DIR$arg1.sh graph data)
			echo "$A" | sed 's/\(.*\.value \)/\1'$EPOCH':/'
		else
			A=$($PLUGIN_DIR$arg1.sh graph)
			echo "$A"
		fi

	else
		echo "# File may not exist, or be non-executeable."
	fi
}
getData() {
	if [ -x "$PLUGIN_DIR$arg1.sh" ]; then
		A=$($PLUGIN_DIR$arg1.sh data)
		echo "$A" | sed 's/\(.*\.value \)/\1'$EPOCH':/'
	else
		echo "# File may not exist, or be non-executeable."
	fi
}


cap() {
# announce capabilities of node
	echo "cap multigraph dirtyconfig"
# check for server annoucement for capabilities
#abilities do not reset at each 'cap' command received,
#e.g. cap mutligraph and then cap dirtyconfig = cap multigraph dirtyconfig
	for i in $arg1
	do
		case $i in
			multigraph)
				USE_MULTIGRAPH=1
			;;
			dirtyconfig)
				USE_DIRTYCONFIG=1
			;;
		esac
	done
}

listen(){
	printf "# munin node at $NODENAME\n"
	while read arg0 arg1
	do
	if [ "$LOG_WRITABLE" = 1 ]; then
		echo "$(date) $arg0 $arg1" >> $LOGFILE
	fi
		case "$arg0" in
			cap)
				cap
			;;
			list)
				if [ $USE_QUICK_LIST = 0 ]; then
					getPlugins
				else
					getPluginsQuick
				fi
			;;
			nodes)
				printf "$NODENAME\n"
				printf ".\n"
			;;
			config)
				getConfig
				printf ".\n"
			;;
			fetch)
				getData
				printf ".\n"
			;;
			easter)
				printf "Kudos. You read the source.\n"
			;;
			version)
				printf "MuninMini v. $VERSION. MuninMini is a basic replacement for munin-node.\n"
			;;
			quit)
				exit 0
			;;
			*)
				printf "# Unrecognised input. Try one of: 'cap <ABILITY>' 'list' 'nodes' 'config <PLUGIN>' 'fetch <PLUGIN>' 'version' 'quit'\n"
				printf "# $PLUGIN_LIST_FINAL \n"
				printf "# PID=$$. PPID=$PPID. USE_QUICK_LIST=$USE_QUICK_LIST. USE_MULTIGRAPH=$USE_MULTIGRAPH. USE_DIRTYCONFIG=$USE_DIRTYCONFIG.\n"
			;;
		esac

	done
}

listen
