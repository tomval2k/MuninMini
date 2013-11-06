#!/bin/sh

#-> allowing this script to read the spool *should* enable it to be ran by munin master
#-> just have to watch out for different capabilities such as multigraph & dirtyconfig
#-> perhaps use a settings files in the spool tarball to check that the capabilities of the master are matching what was sent to the node

#	argX=$@
#	if [ "$argX" == "getSpool" ]; then
#		echo "# need to read values from the spool rather than get live data"
#	fi	

VERSION="0.9.6-Alpha"
# NODENAME="host.domain"
NODENAME="$(cat /proc/sys/kernel/hostname).$(cat /proc/sys/kernel/domainname)"

SPOOL_DIR="/tmp/munin-spool/"

#-> note: plugin files must be executable
PLUGIN_SUB_DIR="plugins.d/"
PLUGIN_DIR=$(echo $0 | sed 's/\(^.*\/\)\(.*\)/\1/')$PLUGIN_SUB_DIR

#echo 1: PWD: $PWD
#echo 2: \$0: $0
#echo 3: $(cd ${0%/*} && echo $PWD/${0##*/})

#echo $PLUGIN_DIR

# LOGFILE="/root/logs/MuninMini.log"
LOGFILE="/tmp/MuninMini.log"

USE_QUICK_LIST=1
USE_MULTIGRAPH=1
USE_DIRTYCONFIG=1
USE_SPOOL=1

#-> create arbitary declaration of time for munin to use as the timestamp when inserting into rrd database to prevent interpolation of integers
EPOCH=$(expr $(date -u +%s) / 300 \* 300)


#-> need to manage spool directory size, at 4kb a tarball, and one every 5 minutes, > 1mb per day
emptySpool() {
	MAXFILES=20

	if [ -d $SPOOL_DIR ]; then
#		ls /tmp/munin-spool/ -Alc | awk 'BEGIN {count=0; total=0} /tar.gz/ { count++; total=$5+total} END { print "total is " total "\ncount is "count }'
#		ls $SPOOL_DIR -Alc | awk 'BEGIN {count=0; total=0} /.tar.gz$/ { count++; if(count > 20){ print $9 } }'
		ls $SPOOL_DIR -Alc | awk 'BEGIN {count=0; total=0} /.tar.gz$/ { count++; if(count > '$MAXFILES'){ cmd="rm '$SPOOL_DIR'"$9; system(cmd)} }'
	fi
}
emptySpool

#-> need to manage log file size, will only be trimmed once it is approx 1.5 times bigger than desired length
trimfile() {
	if [ ! -w $1 ]; then
		return 1
	fi
	TRIGGERLENGTH=$(( $2 * 15 / 10 ))
	LINECOUNT=$(awk 'END {print NR}' $1)
	LINESTOGO=$(( $LINECOUNT - $2))

#	echo length is $LINECOUNT, chopping $LINESTOGO, trigger is $TRIGGERLENGTH, file is $1, newlength is $2
	if [ $LINECOUNT -gt $TRIGGERLENGTH ]; then
		sed -i '1,'$LINESTOGO'd' $LOGFILE
	fi
}
getPluginsQuick() {
	PLUGIN_LIST="conntrack cpu interrupts irqstats load mem netstat processes quotaCheck uptime"
	PLUGIN_LIST_MULTI="bw_multi conntrack cpu interrupts irqstats load mem netstat ping_multi processes quotaCheck uptime"
	PLUGIN_LIST_FINAL=

	if [ $USE_MULTIGRAPH = 1 ]; then
		PLUGIN_LIST_FINAL=$PLUGIN_LIST
	else
		PLUGIN_LIST_FINAL=$PLUGIN_LIST_MULTI
	fi
	echo $PLUGIN_LIST_FINAL
}

getPlugins() {
	PLUGIN_LIST=
	PLUGIN_LIST_FINAL=

	if [ $USE_MULTIGRAPH = 1 ]; then
		PLUGIN_LIST=$(ls -l $PLUGIN_DIR| awk '/.sh$/ && !/multi.sh$/ { n=gensub(/.sh$/, "", 1, $9); printf n " "} ')
	else
		PLUGIN_LIST=$(ls -l $PLUGIN_DIR| awk '/.sh$/ { n=gensub(/.sh$/, "", 1, $9); printf n " "} ')
	fi

	PLUGIN_LIST_FINAL=$PLUGIN_LIST
	echo $PLUGIN_LIST_FINAL
}

getConfig() {
	if [ -x "$PLUGIN_DIR$arg1.sh" ]; then
		if [ $USE_DIRTYCONFIG = 0 ]; then
			A=$($PLUGIN_DIR$arg1.sh graph data)
			echo "$A" | sed 's/\(^[a-z]\+\.value \)/\1'$EPOCH':/'	
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
		echo "$A" | sed 's/\(^[a-z]\+\.value \)/\1'$EPOCH':/'
	else
		echo "# File may not exist, or be non-executeable."
	fi
}

cap() {
#-> announce capabilities of node
	echo "cap multigraph dirtyconfig spool"
#-> check for server annoucement for capabilities
	for i in $arg1
	do
		case $i in
			multigraph)
				USE_MULTIGRAPH=0
			;;
			dirtyconfig)
				USE_DIRTYCONFIG=0
			;;
			spool)
				USE_SPOOL=0
			;;
		esac	
	done
}

createSpool(){
#-> 1: save output to files locally
#-> 2: upload files to remote directory, perhaps as a tarball
#-> 3: use cmd: protocol on munin master to read files from spool location
#-> [if you go to https://duckduckgo.com/?q=epoch+$EPOCH you can convert the time to a readable format]

	echo "# saving plugin output to spool"

	SPOOL_SUB_DIR=$SPOOL_DIR$NODENAME.$EPOCH
	SPOOL_ARCHIVE=$SPOOL_DIR$NODENAME.$EPOCH.tar.gz
	SPOOL_ARCHIVE_LATEST=$SPOOL_DIR$NODENAME.latest.tar.gz
	SPOOL_INDEX=$SPOOL_DIR/index.txt
	SPOOL_MD5=

	mkdir -p $SPOOL_DIR
	mkdir -p $SPOOL_SUB_DIR

#-> loop through plugins to create spool files
	for i in $PLUGIN_LIST_FINAL; do
		if [ $USE_DIRTYCONFIG = 1 ]; then
			"$PLUGIN_DIR$i".sh graph > $SPOOL_SUB_DIR/$i.txt
			"$PLUGIN_DIR$i".sh data | sed 's/\(^[a-z]\+\.value \)/\1'$EPOCH':/' >> $SPOOL_SUB_DIR/$i.txt
		else
			"$PLUGIN_DIR$i".sh graph data | sed 's/\(^[a-z]\+\.value \)/\1'$EPOCH':/' > $SPOOL_SUB_DIR/$i.txt
		fi
	done

#-> create archive, add reference to index file
	tar -cz -C $SPOOL_DIR -f $SPOOL_ARCHIVE $NODENAME.$EPOCH
	rm -r $SPOOL_DIR/$NODENAME.$EPOCH/

	SPOOL_MD5=$(md5sum $SPOOL_ARCHIVE | awk '{ print $1}')

	echo "$NODENAME.$EPOCH, $(date +%D.%T), archived, $SPOOL_MD5" >> $SPOOL_INDEX
	echo "# $NODENAME.$EPOCH, $(date +%D.%T), archived, $SPOOL_MD5...plugin output saved...see $SPOOL_ARCHIVE"

	trimfile $SPOOL_INDEX 150

#-> either do something with the archive within this script like upload it somewhere, or make it really easy to find for something else
#	cp $SPOOL_ARCHIVE $SPOOL_ARCHIVE_LATEST
	rm $SPOOL_ARCHIVE_LATEST
	ln -s $SPOOL_ARCHIVE $SPOOL_ARCHIVE_LATEST
}

listen(){
	printf "# munin node at $NODENAME\n"
	while read arg0 arg1
	do
		echo "$(date) $arg0 $arg1" >> $LOGFILE
		case "$arg0" in
			cap)
				cap
			;;
			list)
				if [ $USE_QUICK_LIST = 1 ]; then
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
			spool)
				if [ $USE_SPOOL = 1 ] || [ -z "$PLUGIN_LIST_FINAL" ]; then
					printf "# BOTH 'cap spool' and 'list' must be called before 'spool'.\n"
					printf "# USE_SPOOL=$USE_SPOOL. Current list: $PLUGIN_LIST_FINAL\n"
				else
					createSpool
				fi
			;;
			easter)
				printf "Kudos. You read the source.\n"
			;;
			version)
				printf "Munin-node written for router with Tomato firmware. Version $VERSION.\n"
			;;
			quit)
				exit 0
			;;
			*)
				printf "# Unrecognised input. Try one of: 'cap <ABILITY>' 'list' 'nodes' 'config <PLUGIN>' 'fetch <PLUGIN>' 'spool' 'version' 'quit'\n"
				printf "# Current list: $PLUGIN_LIST_FINAL\n"
				printf "# PID=$$. PPID=$PPID. USE_QUICK_LIST=$USE_QUICK_LIST. USE_MULTIGRAPH=$USE_MULTIGRAPH. USE_DIRTYCONFIG=$USE_DIRTYCONFIG. USE_SPOOL=$USE_SPOOL. EPOCH=$EPOCH\n"
			;;
		esac

	done
}

listen
