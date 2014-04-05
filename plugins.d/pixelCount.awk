#!/usr/bin/awk -f

#-> script will either receive:
#->  <scriptname> data
#->  <scriptname> graph
#->  <scriptname> graph data


BEGIN {

	graphonly = 1;
	dataonly = 1;
	dirtyconfig = 1;

#-> need to capture arguments passed to script as these get overwritten by hardcoded filename
	if( ARGV[1] == "data" ){
#		print "should do data stuff!";
		dataonly = 0;
	}
	else if (( ARGV[1] == "graph" ) && ( ARGV[2] == "data" )){
#		print "is dirtyconfig"
		dirtyconfig = 0;
	}
	else if ( ARGV[1] == "graph" ){
#		print "just output graph stuff"
		graphonly = 0;
	}
	else {
		print "# You should panic. Or affix either 'graph' or 'data' to the command you called this script with."
		print "# e.g. <scriptname> data"
#-> the exit will send awk to tne END block to avoid file errors and further processing within BEGIN
		exit;
	}

	if (( graphonly == 0 ) || ( dirtyconfig == 0 )){
#		print "a graph request has been submitted";
#-> unlike in shell, multiple print/echo commands don't take noticable time	
#-> TODO: could be more informative about how pixelserv does this/improve *.info
		print "graph_title pixelserv";				
		print "graph_args --base 1000 -l 0";
		print "graph_vlabel Requests";
#		print "graph_category system";
		print "graph_info Pixelserv blocks adverts by serving null requests to clients.";
		print "req.info Total number of requests.";
		print "req.label Requests";
		print "err.info Number of errors.";
		print "err.label Errors";
		print "gif.info Number of gifs requests.";
		print "gif.label gifs";
		print "bad.info Number of bad requests.";
		print "bad.label bad";
		print "txt.info Number of txt requests.";
		print "txt.label txt";
		print "jpg.info Number of jpg requests.";
		print "jpg.label jpg";
		print "png.info Number of png requests.";
		print "png.label png";
		print "swf.info Number of swf requests.";
		print "swf.label swf";
		print "ssl.info Number of ssl requests.";
		print "ssl.label ssl";
	}
	
	if (( dataonly == 0 ) || ( dirtyconfig == 0 )){
#		print "a data request has been submitted";
		ARGV[1] = "/var/log/messages";
		ARGC = 2;
		system("kill -usr1 $(pidof pixel34_full)")
		}
	else {
#		print "else";
#-> the exit will send awk to tne END block to avoid file errors
		exit;
	}
}

	/daemon.info pixelserv/ { count++; }
END {

#-> only parse data if 'dataonly' or 'dirtyconfig'
	if (( dataonly == 0 ) || ( dirtyconfig == 0 )){
		if(count > 0){
			gsub(/.*: /, "");
			gsub(/,/, "");
			print $2".value",$1 "\n" $4".value",$3 "\n" $6".value",$5 "\n" $8".value",$7 "\n" $10".value",$9 "\n" $12".value",$11 "\n" $14".value",$13 "\n" $16".value",$15 "\n" $18".value",$17;
		}
	}
	else {
#		print "end else"
	}
}