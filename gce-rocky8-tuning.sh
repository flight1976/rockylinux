#!/bin/bash

# Install EPEL repo
yum -y install epel-release

# Change yum repo to Taiwan mirror site (http://mirror01.idc.hinet.net/centos)
# backup config
mkdir -p /root/.linux-tunning-bak
tar zcvf /root/.linux-tunning-bak/etc-yum.repo.d-bak.tgz /etc/yum.repos.d


# Use find + sed searching and replacing string, set repo to mirror01.idc.hinet.net(Taiwan mirror)
#find /etc/yum.repos.d -type f -name Rocky-BaseOS.repo -exec sed -i 's/#baseurl=http:\/\/dl.rockylinux.org\/$contentdir/baseurl=http:\/\/mirror01.idc.hinet.net\/rocky/' {} \;
#find /etc/yum.repos.d -type f -name Rocky-BaseOS.repo -exec sed -i 's/^mirrorlist/#mirrorlist/' {} \;

#find /etc/yum.repos.d -type f -name Rocky-AppStream.repo -exec sed -i 's/#baseurl=http:\/\/dl.rockylinux.org\/$contentdir/baseurl=http:\/\/mirror01.idc.hinet.net\/rocky/' {} \;
#find /etc/yum.repos.d -type f -name Rocky-AppStream.repo -exec sed -i 's/^mirrorlist/#mirrorlist/' {} \;

#find /etc/yum.repos.d -type f -name Rocky-PowerTools.repo -exec sed -i 's/#baseurl=http:\/\/dl.rockylinux.org\/$contentdir/baseurl=http:\/\/mirror01.idc.hinet.net\/rocky/' {} \;
#find /etc/yum.repos.d -type f -name Rocky-PowerTools.repo -exec sed -i 's/^mirrorlist/#mirrorlist/' {} \;

#find /etc/yum.repos.d -type f -name Rocky-Extras.repo -exec sed -i 's/#baseurl=http:\/\/dl.rockylinux.org\/$contentdir/baseurl=http:\/\/mirror01.idc.hinet.net\/rocky/' {} \;
#find /etc/yum.repos.d -type f -name Rocky-Extras.repo -exec sed -i 's/^mirrorlist/#mirrorlist/' {} \;

#find /etc/yum.repos.d -type f -name epel.repo -exec sed -i 's/#baseurl=https:\/\/download.example\/pub/baseurl=http:\/\/mirror01.idc.hinet.net/' {} \;
#find /etc/yum.repos.d -type f -name epel.repo -exec sed -i 's/^metalink/#metalink/' {} \;

#find /etc/yum.repos.d -type f -name epel-modular.repo -exec sed -i 's/#baseurl=https:\/\/download.example\/pub/baseurl=http:\/\/mirror01.idc.hinet.net/' {} \;
#find /etc/yum.repos.d -type f -name epel-modular.repo -exec sed -i 's/^metalink/#metalink/' {} \;


#dnf config-manager --set-disabled appstream
dnf config-manager --set-enabled powertools

# Install some daily use packages.
dnf -y install net-tools wget curl telnet lftp tcpdump vim iptables-services tmux

# Disable firewalld and enable iptables-service
systemctl disable firewalld.service
systemctl stop firewalld.service
systemctl enable iptables.service
systemctl start iptables.service
systemctl enable ip6tables.service
systemctl start ip6tables.service

# Customize vim env
cat > /root/.vimrc << EOF
set background=dark

EOF

# Customize bash env
cat > /etc/profile.d/bash_color.sh << EOF
export PS1="\[$(tput bold)\]\[\033[38;5;11m\]\u\[$(tput sgr0)\]@\[$(tput sgr0)\]\[$(tput bold)\]\[\033[38;5;10m\]\h\[$(tput sgr0)\]:\[$(tput sgr0)\]\[$(tput bold)\]\[\033[38;5;6m\][\w]\[$(tput sgr0)\]\\$ \[$(tput sgr0)\]"
EOF

# 改用tmux, 若需要沿用screen可開啟以下設定
#cat > ~/.screenrc << EOF
#termcap xterm 'is=\E[r\E[m\E[2J\E[H\E[?7h\E[?1;4;6l'
#terminfo xterm 'is=\E[r\E[m\E[2J\E[H\E[?7h\E[?1;4;6l'
#EOF

# Setup out firewall script in /etc/fwrules
#
mkdir -p /etc/fwrules
cat > /etc/fwrules/iptables << EOF
#!/bin/bash
PATH=/sbin:/usr/sbin:/bin:/usr/local/sbin:/usr/bin
NATOUT="eth0"
OUTIF="eth0"
INIF="eth1"


## RESET ALL RULES ##
iptables -F
iptables -X
iptables -F -t nat
iptables -F -t mangle

## INPUT ##
#block invalid SYN packet
#reference:
#http://www.webhostingtalk.com/showthread.php?t=363499
#http://www.kb.cert.org/vuls/id/464113
#http://phorum.study-area.org/index.php?topic=5195.0
iptables -A INPUT -i \$OUTIF -p tcp --tcp-flags ALL ACK,RST,SYN,FIN -j DROP
iptables -A INPUT -i \$OUTIF -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
iptables -A INPUT -i \$OUTIF -p tcp --tcp-flags SYN,RST SYN,RST -j DROP

iptables -A INPUT -i \$OUTIF -p all -s whitelist.example.com/32 -j ACCEPT

# for GCP https://console.cloud.google.com IAP ssh
# https://cloud.google.com/iap/docs/using-tcp-forwarding
iptables -A INPUT -i \$OUTIF -p tcp 35.235.240.0/20 --dport 22 -j ACCEPT -m comment --comment "Google IAP ssh"

#iptables -A INPUT -i \$INIF -p all -j ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT ! -i lo -m state --state NEW,INVALID -j DROP

## NAT ##
#iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o \$NATOUT -j SNAT --to-source 10.10.10.1
#iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o \$NATOUT -j MASQUERADE

## PREROUTING ##
#iptables -A PREROUTING -t nat -p tcp -d 10.10.10.1/32 --dport 3389 -j DNAT --to 192.168.1.1:3389

## FORWARD ##
iptables -P FORWARD DROP
#iptables -A FORWARD -s 192.168.1.0/24 -j ACCEPT

iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m state --state NEW,INVALID -j DROP

# PING flow control
iptables -N ping
iptables -A ping -p icmp --icmp-type echo-request -m limit --limit 20/sec -j ACCEPT
iptables -A ping -p icmp -j DROP
iptables -I INPUT -p icmp --icmp-type echo-request -m state --state NEW -j ping


#

## SAVE CONFIGURATION##
iptables-save > /etc/sysconfig/iptables
EOF
chmod a+x /etc/fwrules/iptables
#create ipv6 ip6tables
cat > /etc/fwrules/v6-ip6tables << EOF
#!/bin/bash
PATH=/sbin:/usr/sbin:/bin:/usr/local/sbin:/usr/bin
NATOUT="em1"
OUTIF="em1"
INIF="em2"
## RESET ALL RULES ##
ip6tables -F
ip6tables -X
ip6tables -F -t mangle

#ipmp v6
ip6tables -A INPUT -i \$OUTIF -p icmpv6 -j ACCEPT

## INPUT ##
#block invalid SYN packet
#reference:
#http://www.webhostingtalk.com/showthread.php?t=363499
#http://www.kb.cert.org/vuls/id/464113
#http://phorum.study-area.org/index.php?topic=5195.0
ip6tables -A INPUT -i \$OUTIF -p tcp --tcp-flags ALL ACK,RST,SYN,FIN -j DROP
ip6tables -A INPUT -i \$OUTIF -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
ip6tables -A INPUT -i \$OUTIF -p tcp --tcp-flags SYN,RST SYN,RST -j DROP

#My home
ip6tables -A INPUT -i \$OUTIF -p all -s 2001:Bxxx:xxxx:1001::/64 -j ACCEPT

#Console
ip6tables -A INPUT -i \$OUTIF -p all -s 2001:bxxx:0:xxxx::227/128 -j ACCEPT

############## Intranet INPUT ##########################
#ip6tables -A INPUT -i \$INIF -p all -j ACCEPT
########################################################

ip6tables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
ip6tables -A INPUT ! -i lo -m state --state NEW,INVALID -j DROP

## FORWARD ##
#ip6tables -P FORWARD DROP
#ip6tables -A FORWARD -s 2001:bxxx:0:xxxx::227/128 -j ACCEPT
ip6tables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ip6tables -A FORWARD -m state --state NEW,INVALID -j DROP

#

## SAVE CONFIGURATION##
ip6tables-save > /etc/sysconfig/ip6tables

EOF
chmod a+x /etc/fwrules/v6-ip6tables

# /etc/profile tuning
sed -i "s/HISTSIZE=1000/HISTSIZE=20000\\nTMOUT=7200/" /etc/profile

# log shell command to /var/log/history
# ref:
# http://webplay.pro/linux/syslog-log-bash-history-every-user.html
# http://stackoverflow.com/questions/3522341/identify-user-in-a-bash-script-called-by-sudo
# https://coderwall.com/p/anphha/save-bash-history-in-syslog-on-centos
cat >> /etc/bashrc << EOF
PROMPT_COMMAND=\$(history -a)
#typeset -r PROMPT_COMMAND

function log2syslog
{
   [ \$SUDO_USER ] && user=\$SUDO_USER || user=\`who am i|awk '{print \$1}'\`
   declare command
   command=\$BASH_COMMAND
   logger -p local1.notice -t bash -i -- "\$user=>\$USER[\$$]" : \$PWD : \$command

}
trap log2syslog DEBUG
EOF

#sed -i "s/HISTSIZE=1000/HISTSIZE=20000\\nTMOUT=7200/" /etc/profile

# update syslog
cat > /etc/rsyslog.d/history.conf << EOF
# history
local1.notice                                           /var/log/history
EOF

# update logrotate
sed -i '1s/^/\/var\/log\/history\n/' /etc/logrotate.d/syslog


#update package
dnf -y update

