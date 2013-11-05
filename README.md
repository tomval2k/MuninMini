MuninMini
=========

A munin node to run from a busybox shell

Installation
============

Basic installation of files to enable running MuninMini.sh from a shell:

    wget https://codeload.github.com/tomval2k/MuninMini/tar.gz/master -O /tmp/MuninMini.tar.gz
    tar -xzv -f /tmp/MuninMini.tar.gz -C /tmp
    mkdir -p /root/scripts/
    mv /tmp/MuninMini-master/ /root/scripts/MuninMini/
    rm /tmp/MuninMini.tar.gz

Then need to done one or more of the following:
  - add/remove plugins as required
  - setup xinetd in order to have this as a server
  - setup a cron task to run MuninMini.sh, spool the data, and then upload to a munin-master
  - create and monitor a SSH tunnel from a munin-master to this node
