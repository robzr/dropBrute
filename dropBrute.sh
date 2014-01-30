#!/bin/sh
#
# dropBrute.sh by robzr
#
# minimalist OpenWRT/dropbear ssh brute force attack banning script
#
# Installation steps:
#
# 1) Optionally edit the variables in the header of this script to customise
#    for your environment
#
# 2) Insert a reference for this rule in your firewall script before you
#    accept ssh, something like:
#
#    iptables -N dropBrute
#    iptables -I input_rule -i br-wan -p tcp --dport 22 -j dropBrute
#    iptables -I input_rule -i br-wan -p tcp --dport 22 -m state --state NEW -m limit --limit 6/min --limit-burst 6 -j ACCEPT
#
# 3) Run the script periodically out of cron:
#
#    echo '*/10 * * * * /usr/sbin/dropBrute.sh 2>&1 >> /tmp/dropBrute.log' >> /etc/crontabs/root
#
# 4) If cron is not enabled, you'll also need to run the following:
#
#    /etc/init.d/cron enable && /etc/init.d/cron start
#
#
# To whitelist hosts or networks, simply add a manual entry to the lease
# file with a leasetime of -1.  This can be done with the following syntax:
#
#    echo -1 192.168.1.0/24 >> /tmp/dropBrute.leases
#
# A static, or non-expiring blacklist of a host or network can also be
# added, just use a lease time of 0.  This can be done with the following syntax:
#
#    echo 0 1.2.3.0/24 >> /tmp/dropBrute.leases

# How many bad attempts before banning. Only the log entries from the 
# current day are checked.
allowedAttempts=10

# How long IPs are banned for after the current day ends.
# default is 7 days
secondsToBan=$((7*60*60*24))

# the "lease" file - defaults to /tmp which does not persist across reboots
leaseFile=/tmp/dropBrute.leases

# This is the iptables chain that drop commands will go into.
# you will need to put a reference in your firewall rules for this
iptChain=dropBrute

# the IP Tables drop rule
iptDropRule='-j DROP'

# the IP Tables whitelist rule
iptWhiteRule='-j RETURN'

# You can put default leasefile entries in the following space.
# Syntax is simply "leasetime _space_ IP_or_network".  A leasetime of -1 is a 
# whitelist entry, and a leastime of 0 is a permanent blacklist entry.
[ -f $leaseFile ] || cat <<__EOF__>>$leaseFile
-1 192.168.1.0/24
__EOF__

# End of user customizable variables (unless you know better :) )

ipt='/usr/sbin/iptables'

[ `date +'%s'` -lt 1320000000 ] && echo System date not set, aborting. && exit -1
$ipt -N $iptChain >&/dev/null

today=`date +'%b %d'`
now=`date +'%s'`
nowPlus=$((now + secondsToBan))

echo Running dropBrute on `date` \($now\)

# find new badIPs
for badIP in `logread|egrep "^$today"|fgrep dropbear|egrep 'login attempt for nonexistent user'\|'bad password attempt for'|sed 's/^.*from //'|sed 's/:.*$//'|sort -u` ; do
  found=`logread|egrep "^$today"|fgrep dropbear|egrep 'login attempt for nonexistent user'\|'bad password attempt for'|sed 's/^.*from //'|sed 's/:.*$//'|fgrep $badIP|wc -l`
  if [ $found -gt $allowedAttempts ] ; then
    if [ `egrep \ $badIP\$ $leaseFile|wc -l` -gt 0 ] ; then
       [ `egrep \ $badIP\$ $leaseFile|cut -f1 -d\ ` -gt 0 ] && sed -i 's/^.* '$badIP\$/$nowPlus\ $badIP\/ $leaseFile
    else
       echo $nowPlus $badIP >> $leaseFile
    fi
  fi
done

# now parse the leaseFile
while read lease ; do
  leaseTime=`echo $lease|cut -f1 -d\ `
  leaseIP=`echo $lease|cut -f2 -d\ `
  if [ $leaseTime -lt 0 ] ; then
    if [ `$ipt -S $leaseChain|egrep \ $leaseIP/32\ \|\ $leaseIP\ |fgrep -- "$iptWhiteRule"| wc -l` -lt 1 ] ; then
      echo Adding new whitelist rule for $leaseIP
      $ipt -I $iptChain -s $leaseIP $iptWhiteRule
    fi
  elif [ $leaseTime -ge 1 -a $now -gt $leaseTime ] ; then
    echo Expiring lease for $leaseIP
    $ipt -D $iptChain -s $leaseIP $iptDropRule
    sed -i /$leaseIP/d $leaseFile
  elif [ $leaseTime -ge 0 -a `$ipt -S $leaseChain|egrep \ $leaseIP/32\ \|\ $leaseIP\ |wc -l` -lt 1 ] ; then
    echo Adding new rule for $leaseIP
    $ipt -A $iptChain -s $leaseIP $iptDropRule
  fi
done < $leaseFile
