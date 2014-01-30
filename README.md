dropBrute
=========
By Rob Zwissler (rob@zwissler.org)

Lightweight fail2ban alternative for OpenWRT 

Runs via cron; inspects ssh log for brute force attacks and blocks via 
iptables.  Includes whitelist and blacklist support.

Initial version posted 10/31/2011 at https://forum.openwrt.org/viewtopic.php?pid=224122


Installation Instructions
-------------------------
DB=/usr/sbin/dropBrute.sh
curl -ko $DB https://raw.github.com/robzr/dropBrute/master/dropBrute.sh
chmod 755 $DB

