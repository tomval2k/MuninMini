MuninMini
=========

A munin node to run from a busybox using awk. Also works on fully fledged systems too.


Installation
============

Basic installation of files to enable running MuninMini.sh from a shell:

    wget https://codeload.github.com/tomval2k/MuninMini/tar.gz/master -O /tmp/MuninMini.tar.gz
    tar -xzv -f /tmp/MuninMini.tar.gz -C /tmp
    mkdir -p /root/scripts/MuninMini/
    cp -r /tmp/MuninMini-master/* /root/scripts/MuninMini/
	rm -r /tmp/MuninMini-master
    rm /tmp/MuninMini.tar.gz

Then need to done one or more of the following:
  - add/remove plugins as required
  - setup xinetd in order to have this as a server
  - setup a cron task to run MuninMini.sh, spool the data, and then upload to a munin-master
  - create and monitor a SSH tunnel from a munin-master to this node


Command-line options
====================

The following can be passed to the node on the command-line, overwriting the defaults:
    'plugins.d=/path/to/plugins'
		This is to ensure the node can always find the plugin directory.
    'spool.d=/path/to/chosen/spool/location/'
		Choose where to store spooled archives of plugin output.
    'node=custom.nodename'
		Specify a chosen nodename.


Plugins
=======

Plugins are stored in 'plugins.d', and unused plugins are stored in 'plugins.d/.unused/'. They can be stored elsewhere, with the location being passed to the node via the command-line.

The node searches the plugin directory in response to the 'list' command. Plugins are checked to see if they are executable, and should two plugins have the same basename only one will be included in the loaded list.

Additionally, plugins with a name such as 'ping_multi.sh', therefore having a basename ending in '_multi', will not be included unless 'cap multigraph' is sent to the node.

		
Features and compatibility
==========================

Stock Munin has certain features such as 'dirtyconfig' and 'multigraph' which are replicated.

'dirtyconfig'
  - allows the munin node to call the plugin once to speed processing to avoid duplicating the workload
  - i.e. get the information required to draw the graph and get the data at the same time

'multigraph'
  - allows one plugin to produce multiple graphs
  - e.g. plugin:ping_multi
      - one graph to represent the ping trip timings
      - a second graph to represent packloss


Some/many extra features that will be found in the real Munin are not supported by this node and/or the plugins, as I did not require them. The idea of this node is that it runs on systems that do have perl and are relatively basic, such as anything running <a href="http://www.busybox.net/">BusyBox</a>.


There is a 'spool-save' command that can be run with, by piping such a command to the node: <code>printf "nodes\ncap dirtyconfig multigraph\nlist\nspool-save\nquit\n" | ./MuninMini.awk</code>

This will save a gzip compressed tarball to '/tmp/munin-awk/spool/' for retreival. Note however that there is no cleanup/rotation operation to prevent thousands of archives filling up all the storage space. (*There is/was with the shell script.)


The node will also insert a timestamp in the form of 'seconds since 1970-01-01 00:00:00 UTC' labelled (perhaps incorrectly) as 'EPOCH' to all data .values received from plugins, e.g. <code>uptime.value 433778.71 -> uptime.value 1396635300:433787.79</code>

This is to prevent rrd on the munin-master interpolating values that it receives. On the munin-master, rrd will interpolate values if the time that the value is received is not on the 5 minute mark. As plugins take time to run, and in my case my node and master were separated by a satellite connection, interpolation happed a lot.

Interpolation is bad if your values do not belong on a sliding scale, such as number of users: you can not have 2.09 users on a system.


shell vs awk
============

Originally, MuninMini was written as a shell script. This worked fine, but performance was not great as to do many things external processes need to be called, such as awk, sed, grep, date...

As awk was getting used a lot to do text processing, it was logical to rewrite the script into one awk script. Then anything awk itself could not handle could be outsorced using a system/getline call.

Some of the performance gains have been negated due to making the awk script compatible with variances of awk and has been tested on:
  - busybox-awk v1.10.2, v1.14.4, v1.19.4
  - GNU Awk 4.0.1
  - mawk 1.3.3 Nov 1996 (yes, this even works on something from the last millennium)

However, using awk brought advantages such as
  - powerful inbuilt regex matching
  - date handling (although removed from this script for compatibility with mawk)
  - arrays that did not have to be cobbled together (useful for mapping nice plugin names to filenames)

Was it worth the effort...


Why not just use MuninLite?
===========================

I did, at least on my <a href="http://wiki.openwrt.org/toh/tp-link/tl-wr703n">TL-WR703N</a> but it did not work on my <a href="https://en.wikipedia.org/wiki/Linksys_WRT54G_series">WRT54GS</a> (at least I do not think it did). So I think I changed a couple of lines here, there, and everywhere.

Soon enough I had basically rewritten MuninLite completely, and then some. Throw in some extra plugins, and MuninLite was no longer fir for <i>my</i> purpose.

Saying all that, some of the plugins might be rather similar to those from MuninLite...I would need to go through them and see what is what.


Other Munin implementations
===========================

Original and active Munin located at:
  - <a href="http://munin-monitoring.org/">Official website -> Munin</a>
  - <a href="https://github.com/munin-monitoring/munin">GitHub -> Munin</a>
  - <a href="http://sourceforge.net/projects/munin/">SourceForge -> Munin</a>

Previous shell incarnation of Munin known as MuninLite:
  - <a href="http://runesk.blogspot.co.uk/2009/03/muninlite-included-in-openwrt-and-new.html">Developer's blog -> MuninLite</a>
  - <a href="http://sourceforge.net/projects/muninlite/">SourceForge -> MuninLite</a>
