#!/usr/bin/awk -f

#-> munin in shell is one thing...now in awk/gawk?

BEGIN {
	VERSION = "0.9.15"
	USE_MULTIGRAPH = 1
	USE_DIRTYCONFIG = 1
	SPOOLDIR = "/tmp/munin-awk/spool/";
#-> gawk->mawk edit
#	EPOCH = systime();
	cmd = "date +%s";
	cmd | getline EPOCH;
	close(cmd);
	EPOCH = EPOCH - (EPOCH % 300)

	PLUGIN_DIR="plugins.d/"


	if ((getline < "/proc/sys/kernel/domainname" tmp) > 0){
		DOMAIN = $RS;
		close(tmp);
	}
	else { DOMAIN = "domain" }
	if ((getline < "/proc/sys/kernel/hostname" tmp) > 0){
		HOST = $RS;
		close(tmp);
	}
	else { HOST = "host" }
	NODENAME = HOST "." DOMAIN;
#->TODO, fix invalid characters of '(none)' as this is part of filename
	NODENAME = "test.domain";
	print "# munin node at " NODENAME;
}

#-> replicate shell case/switch by reading input from command line
$1 == "cap"	{
	print "cap multigraph dirtyconfig";
#	print $RS;
	for(i=2; i<=NF; i++)
	{
#	print "for: " $i
		if ( $i == "multigraph" ){
			USE_MULTIGRAPH = 0;
		}
		else if ( $i == "dirtyconfig" ){
			USE_DIRTYCONFIG = 0;
		}
		else {
			print "# Error: '" $i "' not recognised as part of '" $RS "'.";
			print "# Error: other capabilities may still have been set.";
		}
	}
	next;
	}
$1 == "list"	{
#-> if there is more than one file in plug directory with common basename,
#-> e.g. uptime.awk and uptime.sh, only uptime.sh is listed
#-> in theory, it is possible to check if the basename already exists and give it a suffix
#	print "listing all files in: " PLUGIN_DIR;
	cmd = "ls " PLUGIN_DIR
	while( cmd | getline line > 0 ) {
#		print line
#-> gawk->mawk edit
#		basename = gensub( /(.*)\..*/, "\\1", 1, line);
		match(line, /^.*\./);
		basename = substr(line, 1, RLENGTH-1);
#		print "line: " line;
#		print "base: " basename;

#-> don't add multigraph
		isMulti = match(basename, /multi$/);
		if (( USE_MULTIGRAPH == 1 ) && (isMulti > 0)){
			continue;
		}
		pluginArr[basename] = line;
	}
	close(cmd)

#-> example, returns 'cpu.sh'
#	print pluginArr["cpu"];

#-> start with empty string (in case 'list' called more than once)
	pluginStr = "";
	for (x in pluginArr) {
		pluginStr = pluginStr " " x;
	}
#-> remove leading spaces from string
	gsub(/^ */, "", pluginStr);
	print pluginStr;
	next;
}

$1 == "nodes"	{
	print NODENAME "\n.";
	next;
}

$1 == "fetch" || $1=="config" || $1 == "spool-save"	{
#-> as can not create a 2-way pipe on router, need to automatically loop through plugins, hence why this in same block

	if ( $1 == "spool-save" ){
#-> 	at minimum need a 'list', and 'cap dirtyconfig...'
		if ( USE_DIRTYCONFIG != 0 ) {
#->			Even more complicated if you are spooling data twice (e.g. once to get config + once to get values)
#->			Does data then get stored separetly...etc, so easy option is to force dirtyconfig.
			print "# Error. Must have dirtyconfig set to use spool-save.";
			next;
		}
		else if ( length(pluginStr) == 0 ) {
			print "# Error. Must have ran 'list' prior to 'spool-save'.";
			next;
		}

		cmdSuffix = " graph data";
#-> 	create directory...
		TMPDIR = SPOOLDIR NODENAME "." EPOCH;

		result = system("mkdir -p " TMPDIR);
		if ( result != 0 ){
			print "# Error. Can not create temporary directory: " TMPDIR;
			exit;
		}
#		print "# Notice. Temporary directory created: " TMPDIR;

	}
	else if ( $1 == "fetch" ){
		cmdSuffix = " data"
	}
	else if (( $1 == "config" ) && ( USE_DIRTYCONFIG == 1 )){
		cmdSuffix = " graph"
	}
	else if (( $1 == "config" ) && ( USE_DIRTYCONFIG == 0 )){
		cmdSuffix = " graph data"
	}
	else {
		print "# Error. Unrecognised options...but really not sure how this message would be shown.";
		next;
	}


#-> if manual, or from two-way munin-master -> munin-node, 'cmd' gets run once,
#-> if spooling, cmd will loop...

#-> reset array when this is called multiple times, (e.g. fetch cpu...fetch uptime...fetch netstat..etc)
#	pluginsToGet = split("", pluginsToGet);

	if ( $1 == "spool-save" ){
		for (x in pluginArr) {
		#	print "pluginArr:" x " ... " pluginArr[x];
			pluginsToGet[x]++;
		}
#		print "option 1";
	}
	else if ( length(pluginArr[$2]) != 0 ) {
		pluginsToGet[$2]++;
#		print "option 2";
	}
	else {
		print "# Error. Something has gone wrong. Not sure how.";
		exit;
	}

###########################################################
	for (p in pluginsToGet){
#		print "plugin is...:" p;
		filename = pluginArr[p];
		if ( length(filename) == 0 ){
			print "# Plugin not found. Was it in 'list'?";
			break;
		}
#				print "# Notice. Plugin was found..." filename;
		cmd = "./" PLUGIN_DIR filename cmdSuffix;
	#	print cmd;
	#	system(cmd)

		while( cmd | getline line > 0 ) {
	#-> 	if part 1 ends .value AND part 2 does NOT contain data-COLON-data, then add epoch
	#-> 	perhaps also have a test to ensure that tempArr is only 2 elements long?
	#->		 -e.g. uptime.value 433778.71 -> uptime.value 1396635300:433787.79
	#-> 	wonder how much of a performance hit this is...
			split(line, tempArr, " ");
			isDotValue = match(tempArr[1], /\.value$/);
			hasTimeStamp = match(tempArr[2], /^[0-9]+:.*$/);
			if (( isDotValue > 0 ) && ( hasTimeStamp == 0 )){
	#			print "no timestamp so add one";
				line = tempArr[1] " " EPOCH ":" tempArr[2];
			}
			if ( $1 == "spool-save" ){
#						print "spool-> " p " -> " filename " -> "line;
				print line > TMPDIR "/" filename ".txt";
			}
			else {
				print line;
			}
		}
		if ( $1 == "spool-save" ){
			close(TMPDIR "/" filename ".txt");
		}
		close(cmd);
#-> gawk-> mawk fix, plus deleting each element of array when it is used is maybe better
	delete pluginsToGet[p];
	}
###########################################################
#	delete pluginsToGet;
	LABEL = NODENAME "." EPOCH;

	if ( $1 != "spool-save" ){
		print ".";
		next;
	}
	cmd = "tar -cz -C " SPOOLDIR " -f " SPOOLDIR LABEL ".tar.gz " NODENAME "." EPOCH;
#	print cmd;
	if (system(cmd) != 0) {
		print "# Error. Could not create *.tar.gz.";
#		exit;
	}
	close(cmd);

	cmd = "rm -rf " SPOOLDIR LABEL;
#	print cmd;
	if (system(cmd) !=0) {
		print "# Error. Could not remove temporary directory.";
#		exit;
	}
	close(cmd);

	cmd = "md5sum " SPOOLDIR LABEL ".tar.gz";
#	print cmd;
	while( cmd | getline line > 0 ) {
		gsub(/ .*$/, "", line);
		MD5 = line;
	}
	close(cmd);
#-> gawk->mawk edit
#	TIMESTAMP = strftime("%d/%m/%Y %H:%M:%S %z");
	cmd = "date +'%d/%m/%Y %H:%M:%S %z'";
	cmd | getline TIMESTAMP;
	close(cmd);

	logLine = LABEL ", " TIMESTAMP ", archived, " MD5;

	print logLine >> SPOOLDIR "index.txt";

	cmd = "ln -sf " SPOOLDIR LABEL ".tar.gz" " " SPOOLDIR NODENAME ".latest.tar.gz" ;
#	print cmd;
	if (system(cmd) !=0) {
		print "# Error. Could not create/update symlink.";
#		exit;
	}
	close(cmd);
	print "# Output from plugins has been saved. [ " SPOOLDIR LABEL ".tar.gz ]";
	next;
}

$1 == "easter"	{
	print "# Kudos. You read the source."
	next;
}

$1 == "version"	{
	print "# Version " VERSION
	print "# Munin-node written for router with Tomato firmware."
	print "# Should be compatible with other devices."
	next;
}

$1 == "quit"	{
	exit;
}

{
	print "# Unrecognised input. Try one of:";
	print "# 'cap <ABILITY>' 'list' 'nodes' 'config <PLUGIN>' 'fetch <PLUGIN>' 'spool-save' 'version' 'quit'";
	print "# Current list: " pluginStr;
	print "# USE_MULTIGRAPH=" USE_MULTIGRAPH ". USE_DIRTYCONFIG=" USE_DIRTYCONFIG ". EPOCH=" EPOCH ".";
}

END {
#	print "All done - at end. Bye!";
}
