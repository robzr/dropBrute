## dropBrute

**dropBrute has been superceeded by [bearDropper](https://github.com/robzr/bearDropper)**

**Lightweight fail2ban alternative for OpenWRT**

Runs via cron; inspects ssh log for brute force attacks and blocks via 
iptables.  Includes whitelist and blacklist support.

Initial version posted 10/31/2011 at https://forum.openwrt.org/viewtopic.php?pid=224122


### Installation Instructions

These installation instructions can be cut and paste into the terminal

Retrieve the latest copy of dropBrute.sh from gitHub

	DB=/usr/sbin/dropBrute.sh
	curl -ko $DB https://raw.github.com/robzr/dropBrute/master/dropBrute.sh
	chmod 755 $DB

Optionally edit the variables in the header of this script to customise

	vi $DB

Insert a reference for this rule in your firewall script before you accept ssh, something like:

	cat >>/etc/firewall.user <<_EOF_
	WANIF=`uci get network.wan.ifname`
	iptables -N dropBrute
	iptables -I input_rule 1 -i $WANIF -p tcp --dport 22 -j dropBrute
	iptables -I input_rule 2 -i $WANIF -p tcp --dport 22 -m state --state NEW -m limit --limit 6/min --limit-burst 6 -j ACCEPT
	_EOF_

Run the script periodically out of cron:

	echo '*/10 * * * * /usr/sbin/dropBrute.sh 2>&1 >> /tmp/dropBrute.log' >> /etc/crontabs/root

If cron is not enabled, you'll also need to run the following:

	/etc/init.d/cron enable && /etc/init.d/cron start

Setup any permanent blacklist/whitelist entries.  The script by default will whitelist your local network, edit the script header to disable this functionality.  To whitelist hosts or networks, simply add a manual entry to the lease file with a leasetime of -1.  This can be done with the following syntax:

	echo -1 192.168.1.0/24 >> /tmp/dropBrute.leases

A static, or non-expiring blacklist of a host or network can also be added, just use a lease time of 0.  This can be done with the following syntax:

	echo 0 1.2.3.0/24 >> /tmp/dropBrute.leases
