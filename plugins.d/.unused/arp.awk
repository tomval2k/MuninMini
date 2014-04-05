#!/usr/bin/awk -f

BEGIN {
	if(( ARGV[1] != "data" ) && ( ARGV[1] != "graph" )){
		print "# You should panic. Or affix 'graph', 'graph data', or 'data' to the command you called this script with.";
		print "# e.g. <scriptname> data";
		exit;
	}

#-> for plugins that use an outside resource for both graph + data, the request for that can go here
#-> 	then within each section, interpret as needed
#-> if graph + data are independent of each other, then just put code into the distinct blocks below

		file = "/proc/net/arp";
		while( (getline < file) > 0 ) {
			count++;
			if(count > 1){
				device[$6]++;
			}
		}
#-> on busybox-awk, if you try to 'close(file)' and the file does not exist, there will be a fatal
#->  error of "Segmentation fault", to prevent this, wrap 'close(file)' with a check for ERRNO,
#->  which busybox-awk does have. If ERRNO does not exist, 'close(file)' should still happen.
		if (ERRNO != 2){
			close(file);
		}

	if( ARGV[1] == "graph" ) {
		print "graph_title Arp Cache";
		print "graph_args --base 1000";
		print "graph_vlabel Count";
		print "graph_category network";
		print "graph_info Arp count for devices on all interfaces.";
		for (dev in device){
			printf ("%s.label %s count\n", dev, dev);
		}
		print "arp.label arp count";
	}

	if( ( ARGV[1] == "data" ) || (( ARGV[1] == "graph" ) && ( ARGV[2] == "data" ))) {
		if (count > 1){
			print "br0.value " device["br0"];
			print "vlan1.value " device["vlan1"];
			print "arp.value " count - 1;
		}
		else {
			print "arp.value 0";
		}
	}
	exit;
}

#->INSTALL INFO START<-#
#->REQUIREMENTS:FILE:/proc/net/arp
#->DIRTYCONFIG:TRUE
#->MULTIGRAPH:FALSE
#->DESCRIPTION:Reports number of IP addresses in from /proc/net/arp, and groups per device (i.e. 'br0', 'vlan1').
#->INSTALL INFO END<-#