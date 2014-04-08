#!/usr/bin/awk -f

#-> should be broadly similar in use to that of munin-async and SpoolReader.pm
#-> i.e.	point it to the spool directory
#->			replay contents of spool directory to munin master
#->			clean up after itself

#-> SpoolReader.pm reads flat files only, no archives

#-> TODO:
#->  - implement cleanup actions (ie remove replayed archive from disk)
#->  - trim index file, 100 bytes per line ~ 10mb per year, too big for my router.
#-> 

BEGIN {
	VERSION = "0.2.0"

#-> print extra messages to screen
	DEBUG = 1;
	
#-> default values that can be changed by passing arguments via command line
	SPOOLDIR	= "/tmp/munin-awk/spool/";

#-> read any supplied values from command line
	for (i in ARGV){
		if (ARGV[i] ~ /^spool.d=/ ) {
			SPOOLDIR = ARGV[i];
			gsub(/^.*=/, "", SPOOLDIR);
		}
		else if (ARGV[i] ~ /^node=/ ) {
			NODENAME = ARGV[i];
			gsub(/^.*=/, "", NODENAME);
		}
#		else if (ARGV[i] ~ /^cleanup=/ ) {
#			cleanup = ARGV[i];
#			gsub(/^.*=/, "", cleanup);
#		}
		else if (ARGV[i] ~ /^debug=/ ) {
			DEBUG = ARGV[i];
			gsub(/^.*=/, "", DEBUG);;
		}
	}

#-> require NODENAME

	if(length(NODENAME) == 0){
		print "# Error. No nodename supplied. Use 'node=' on command line.";
		exit;
	}

#-> force trailing slash on directories
	sub(/[^\/]$/, "&/", SPOOLDIR);

#-> limit supplied epoch
#-> could just have a check to see if greater than 0, but do not forsee either date being broken
#-> 1000000000 = Sun Sep 09 01:46:40 2001 +0000
#-> 9000000000 = Wed Mar 14 16:00:00 2255 +0000
	EPOCH_min = 1000000000;
	EPOCH_min = 1;
	EPOCH_max = 9000000000;

	node_index = SPOOLDIR NODENAME ".index.txt";
	
#-> dump variables to screen
	if( DEBUG == 0 ){
		print "--spooldir: " SPOOLDIR;
		print "--nodename: " NODENAME;
		print "--cleanup: " cleanup;
		print "--epoch: " EPOCH;
		print "--debug: " DEBUG;
		print "--node_index: " node_index;
	}

#-> scan spool directory for index file belonging to node
	while( (getline line < node_index) > 0 ) {
		if( DEBUG == 0 ){
			print line;
		}
		split(line, value, ", ");
		if ( value[4] == "archived" ){
			archive = NODENAME "." value[2] ".tar.gz"
			archives[archive]++;
			epochs[value[2]]++;
			count++;
		}
	}
	if (ERRNO != 2){
		close(node_index);
	}
	
	if( DEBUG == 0 ){
		printf("%3d archives found for %s\n", count, NODENAME);
		count = 0;
	}

#-> now untar, to stdout, so awk can get info	
#-> *think* munin-async replays the spool to munin-master by
#-> going through each plugin only once, then moving onto next
#-> it uses the line 'timestamp 1396879302' to recognise that it is at a new response
#-> but does not pront this line, but inserts the epoch from that line into
#-> the response as label.value epoch:data

#-> as my spool system archives the plugin output on each run, i need to extract all archives
#-> for the node, and put all the responses for each plugin into one array, then 

#-> create some spooled data
# printf "cap dirtyconfig\nlist\nspool-save\nquit" | ./MuninMini.awk


	for (timestamp in epochs){
		cmd = "tar -xzO -f " SPOOLDIR NODENAME "." timestamp ".tar.gz";

		if( DEBUG == 0 ){
			count++;
			print count;;
			print cmd;
		}

		while( (cmd | getline line) > 0 ){
		#	print "from archive: " line;
			if ( line ~ /^#SPOOL-BEGIN:/ ){
				sub(/^#SPOOL-BEGIN:/, "", line);
				plugin = line;
				plugins_found[plugin]++;
		#		print "start of plugin data: " plugin;
			}
			else if ( line ~ /^#SPOOL-END:/ ){
			#	print "end of plugin data: " plugin;
			}
			else{
		#		print line;
		#		print plugin;
				if( plugin_data[plugin "_" timestamp] != "" ){
					plugin_data[plugin "_" timestamp] = plugin_data[plugin "_" timestamp] "\n" line;
				}
				else {
		#			print "else";
					plugin_data[plugin "_" timestamp] = line;
				}
			}
			
			#SPOOL-BEGIN:" uptime
			#SPOOL-END:" uptime
			
		}
		if (ERRNO != 2){
			close(cmd);
		}

#ONLY FOR TESTING, just want 1 loop
#	break;
	}
	
#	for (item in plugins_found) {
#		print item;
#	}
	
#	for (q in plugin_data) {
#		print q;
#		print plugin_data[q];
#	}

	if( DEBUG == 0 ){
		for (e in epochs) {
			print "epochs found in index: " e;
		}
	}

#	print plugin_data["uptime_1396893600"];
#	exit;
	print "# munin node at " NODENAME;
}

$1 == "list" {
	for (item in plugins_found) {
		printf item " ";
	}
	printf "\n";
	next;
}

$1 == "spoolfetch" {
	if (( $2 < EPOCH_min ) || ( $2 > EPOCH_max)){
		print "# Supplied epoch was out of range.";
		next;
	}
	epoch_matched = 1;
	for (e in epochs){
		if( e >= $2 ){
			epoch_matched = 0;
			matched[e]++;
#			printf("GTE: %d e, %d $2, \n", e, $2);
#			print "get me!";
			for ( item in plugins_found ) {
				print plugin_data[item "_" e];
			}
		}
	}
	if ( epoch_matched == 1 ){
		print "# No spool data found to replay to server.";
	}
#-> is this next print necessary?
	print ".";
	next;
}

$1 == "ping"	{
	print "pong"
	next;
}

$1 == "version"	{
	printf ("# node spool -> master replay script. Version %s.\n", VERSION);
	next;
}

$1 == "cap"	{
	print "cap spool";
	next;
}

$1 == "quit"	{
	exit;
}

{
	print "# Command not found/implemented..";
	next;
}
END {
	for ( e in matched ){
		if( DEBUG == 0 ){
			printf("Replayed to server: %20s \t %10d\n", NODENAME, e);
		}
		#-> convert array to string, then can use match() against string rather than looping through array
		matched_epoch_str = matched_epoch_str " " e;
	}

	if( length(matched_epoch_str) != 0 ){
		while( (getline line < node_index) > 0 ) {
			split(line, value, ", ");
			mf = match(matched_epoch_str, value[2]);
			if( DEBUG == 0 ){
				print line;
				print "matching " value[2] " against string: " matched_epoch_str " and match() returned " mf;
			}
				if( mf > 0 ){
					data = value[1] ", " value[2] ", " value[3] ", spool-read, " value[5];
				}
				else {
					data = line;
				}
			if ( output != "" ){
				output = output "\n" data;
			}
			else {
				output = data;
			}
		}
		if (ERRNO != 2){
			close(node_index);
		}

		if( DEBUG == 0 ){
			print "contents of new file...";
			print output;
		}
	
		#-> now write file
		cmd = "mv " node_index " " node_index ".old";
		if( DEBUG == 0 ){
			print cmd;
		}
		system(cmd);
		print output > node_index;
	}
	print "# Bye!";
}

