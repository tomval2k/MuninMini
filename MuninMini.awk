#!/usr/bin/awk -f

#-> munin in shell is one thing...now in awk/gawk/mawk

BEGIN {
	VERSION = "0.11.0"

#-> default values that can be changed by passing arguments via command line
	SPOOLDIR	= "/tmp/munin-awk/spool/";
	PLUGINDIR	= "plugins.d/"
	NODENAME	= ""

#-> read any supplied values from command line
	for (i in ARGV){
		if (ARGV[i] ~ /^plugins.d=/ ) {
			PLUGINDIR = ARGV[i];
			gsub(/^.*=/, "", PLUGINDIR);
		}
		else if (ARGV[i] ~ /^spool.d=/ ) {
			SPOOLDIR = ARGV[i];
			gsub(/^.*=/, "", SPOOLDIR);
		}
		else if (ARGV[i] ~ /^node=/ ) {
			NODENAME = ARGV[i];
			gsub(/^.*=/, "", NODENAME);
		}
	}

#-> force trailing slash on directories
	sub(/[^\/]$/, "&/", PLUGINDIR);
	sub(/[^\/]$/, "&/", SPOOLDIR);
#-> other values (changed in response to munin server input)
	USE_MULTIGRAPH = 1
	USE_DIRTYCONFIG = 1
#-> gawk->mawk edit (mawk does not have systime() function)
#	EPOCH = systime();
	cmd = "date +%s";
	cmd | getline EPOCH;
	close(cmd);
	EPOCH = EPOCH - (EPOCH % 300)

#-> if no NODENAME defined, get one from system values

	if(NODENAME == ""){
		if ((getline < "/proc/sys/kernel/domainname" tmp) > 0){
			DOMAIN = $RS;
			close(tmp);
		}
		else { DOMAIN = "domain"; }
		if ((getline < "/proc/sys/kernel/hostname" tmp) > 0){
			HOST = $RS;
			close(tmp);
		}
		else { HOST = "host"; }

	#-> '/proc/sys/kernel/domainname' may return '(none)', which is fine until attempting to write to a filesystem
	#-> so if there is some form of hostname, ignore the domainname if it is '(none)'
	#-> all use gsub to remove any '()' from final NODENAME
		if (( DOMAIN == "(none)" ) && ( length(HOST) > 0 )){
			NODENAME = HOST;
		}
		else {
			NODENAME = HOST "." DOMAIN;
		}
	}

#-> remove blacklist of characters from NODENAME, and warn if NODENAME length is now zero.
	gsub(/[()]/, "", NODENAME);
	if(length(NODENAME) == 0){
		print "# Error. No usable nodename defined in system or passed with commandline.";
		exit;
	}
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
#	print "listing all files in: " PLUGINDIR;
	cmd = "ls -l " PLUGINDIR
	while( cmd | getline line > 0 ) {
#		print line
		split(line, parts)
#-> check if file is executable (very basic, no owner checks etc)
		if (parts[1] !~ /^-rwx/ ) {
#			print "not executable" parts[1] " ... " parts[9];
			continue;
		}
		fullname = parts[9];
#-> match() will set inbuilt variable RLENGTH
		match(fullname, /^.*\./);
		basename = substr(fullname, 1, RLENGTH-1);
#		print "line: " line;
#		print "base: " basename;

#-> don't add multigraph
		isMulti = match(basename, /multi$/);
		if (( USE_MULTIGRAPH == 1 ) && (isMulti > 0)){
			continue;
		}
		pluginArr[basename] = fullname;
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
	gsub(/^ +/, "", pluginStr);
	print pluginStr;
	next;
}

$1 == "nodes"	{
	print NODENAME "\n.";
	next;
}

$1 == "fetch" || $1=="config" || $1 == "spool-save"	{
#-> as can not create a 2-way pipe on router, need to automatically loop through plugins, hence why this in same block

	if ( length(pluginStr) == 0 ) {
		print "# Error. Must have ran 'list' prior to 'fetch <plugin>', 'config <plugin>', or 'spool-save'.";
		next;
	}

	if ( $1 == "spool-save" ){
#-> 	at minimum need a 'list', and 'cap dirtyconfig...'
		if ( USE_DIRTYCONFIG != 0 ) {
#->			Even more complicated if you are spooling data twice (e.g. once to get config + once to get values)
#->			Does data then get stored separetly...etc, so easy option is to force dirtyconfig.
			print "# Error. Must have ran 'cap dirtyconfig' to use 'spool-save'.";
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
	else if ( length(pluginArr[$2]) == 0 ) {
		print "# Error. Supplied plugin of '" $2 "' not in list.";
		delete pluginArr[$2];
		next;
	}
	else {
		print "# Error. Something has gone wrong. Not sure how.";
		exit;
	}
###########################################################
	for (p in pluginsToGet){
#		if ( $1 == "spool-save" ){
#			print "# Info plugin is: " p;
#		}
		filename = pluginArr[p];
		if ( length(filename) == 0 ){
			print "# Plugin not found. Was it in 'list'?";
			print "# looking for: " filename " ... " p;
			break;
		}
#				print "# Notice. Plugin was found..." filename;
		cmd = PLUGINDIR filename cmdSuffix;
	#	print cmd;
	#	system(cmd)

		if ( $1 == "spool-save" ){
			print "#SPOOL-BEGIN:" p > TMPDIR "/" filename ".txt";
		}
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
			print "#SPOOL-END:" p > TMPDIR "/" filename ".txt";
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

	logLine = NODENAME ", " EPOCH ", " TIMESTAMP ", archived, " MD5;

	print logLine >> SPOOLDIR NODENAME ".index.txt";

	cmd = "ln -sf " SPOOLDIR LABEL ".tar.gz" " " SPOOLDIR NODENAME ".latest.tar.gz" ;
#	print cmd;
	if (system(cmd) !=0) {
		print "# Error. Could not create/update symlink.";
#		exit;
	}
	close(cmd);
	print "# Plugin responses spooled to: " SPOOLDIR LABEL ".tar.gz";
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
