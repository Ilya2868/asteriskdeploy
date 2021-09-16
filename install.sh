#!/bin/bash
cd /usr/src/asteriskdeploy
#set timezone
timedatectl set-timezone 'Europe/Moscow'

#disable SELinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

#add repos
yum install -y epel-release && yum install -y deltarpm && yum update -y
rpm -ivh http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
curl -sL https://rpm.nodesource.com/setup_10.x | sudo bash -
rpm -ivh http://rpms.remirepo.net/enterprise/remi-release-7.rpm
rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
rpm -ivh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-1.el7.nux.noarch.rpm
rpm -ivh https://cbs.centos.org/kojifiles/packages/iksemel/1.4/6.el7/x86_64/iksemel-1.4-6.el7.x86_64.rpm
rpm -ivh https://cbs.centos.org/kojifiles/packages/iksemel/1.4/6.el7/x86_64/iksemel-devel-1.4-6.el7.x86_64.rpm

#install needed packages
yum -y install --enablerepo=remi-php73 iptables-utils iptables-services fail2ban mysql-server mysql-connector-odbc-8.0.19-1.el7.x86_64 composer mc nginx wget htop atop iotop net-tools gcc gcc-c++ lynx bison mysql-devel e2fsprogs-devel keyutils-libs-devel krb5-devel libogg libselinux-devel libsepol-devel gmp gnutls-devel libogg-devel openssl-devel zlib-devel perl-DateManip tftp-server httpd make ncurses-devel libtermcap-devel sendmail sendmail-cf caching-nameserver sox newt-devel libxml2-devel libtiff-devel audiofile-devel gtk2-devel subversion kernel-devel git crontabs cronie cronie-anacron vim uuid-devel libtool libtool-ltdl-devel sqlite-devel libuuid-devel sqlite unixODBC unixODBC-devel texinfo curl-devel net-snmp-devel neon-devel speex-devel gsm-devel spandsp-devel mc htop doxygen path svn gmpgnutls-devel nodejs ffmpeg ffmpeg-devel unzip lame php php-fpm php-gd php-mysql php-xml rsync
systemctl stop firewalld && systemctl disable firewalld



#build asterisk
wget http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/asterisk-16.7.0.tar.gz -O /usr/src/asteriskdeploy/asterisk.tar.gz
cd /usr/src/asteriskdeploy/
tar -xf ./asterisk.tar.gz
cd /usr/src/asteriskdeploy/asterisk-16.7.0
./contrib/scripts/install_prereq install
./configure --libdir=/usr/lib64 --with-jansson-bundled
make -j 4 && make install
make samples
make config
useradd -m asterisk

#file operations
cd /usr/src/asteriskdeploy/
unzip files.zip
rm -rf /etc/nginx/*
rm -rf /etc/fail2ban/jail.d/*
rm -rf /etc/php-fpm.d/*
rsync -avz ./etc/ /etc/
rsync -avz ./var_lib/asterisk/ /var/lib/asterisk/


chown asterisk. /var/run/asterisk
chown -R asterisk. /etc/asterisk
chown -R asterisk. /usr/lib64/asterisk
chown -R asterisk. /var/{lib,spool,log}/asterisk/

#enable & start services
systemctl enable asterisk
systemctl enable fail2ban
systemctl enable nginx
systemctl enable php-fpm
systemctl enable mysqld
systemctl enable iptables
systemctl start iptables
systemctl start mysqld
systemctl start php-fpm
systemctl start asterisk
systemctl start nginx
systemctl start fail2ban

#init mysql setup 
mysql_secure_installation <<EOF

y
asd123
asd123
y
y
y
y
EOF

#set limits to mysqld
mkdir -p /usr/lib/systemd/system/mysqld.service.d
cat <<EOF > /usr/lib/systemd/system/mysqld.service.d/limit.conf
[Service]
LimitNOFILE=55000
EOF
systemctl daemon-reload && systemctl restart mysqld


#logrotate

cd /etc/logrotate.d/

touch asterisk

cat <<EOF > /etc/logrotate.d/asterisk
/var/log/asterisk/queue_log
/var/log/asterisk/full
/var/log/asterisk/security {
daily
compress
missingok
rotate 7
dateext
notifempty
sharedscripts
create 0640 asterisk asterisk
su asterisk asterisk
postrotate
/usr/sbin/asterisk -rx 'logger reload' > /dev/null 2> /dev/null
endscript
}
EOF


#crontab

cat <<EOF > /var/spool/cron/root
00 08 * * * /var/lib/asterisk/agi-bin/iamyandex 2> /tmp/ya
EOF


#set up firewall
export IPT="iptables"
for WAN in $(ls /sys/class/net |grep -m1 e); do export $WAN; done
#Удалить все правила
$IPT -F
#Удалить все правила в цепочках nat and mangle
$IPT -F -t nat
$IPT -F -t mangle
#удалить пользовательские цепочки
$IPT -X

$IPT -t nat -X
$IPT -t mangle -X

# блокировать трафик, если он не совпадает с правилами
$IPT -P INPUT DROP
#$IPT -P OUTPUT DROP
#$IPT -P FORWARD DROP

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>> SIP <<~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$IPT -N SIP
# доступ SIP
$IPT -A SIP -p udp -m udp -m string --string "sipcli" --algo bm --to 65535 -j DROP
$IPT -A SIP -p udp -m udp -m string --string "friendly-scanner" --algo bm --to 65535 -j DROP
$IPT -A SIP -p udp -m udp -m string --string "VaxSIPUserAgent" --algo bm --to 65535 -j DROP
$IPT -A SIP -p udp -m udp -m string --string "sip-scan" --algo bm --to 65535 -j DROP
$IPT -A SIP -p udp -m udp -m string --string "iWar" --algo bm --to 65535 -j DROP
$IPT -A SIP -p udp -m udp -m string --string "sipvicious" --algo bm --to 65535 -j DROP
$IPT -A SIP -p udp -m udp -m string --string "sipsak" --algo bm --to 65535 -j DROP
$IPT -A SIP -p udp -m udp -m string --string "sundayddr" --algo bm --to 65535 -j DROP
$IPT -A SIP -p udp -m udp -m string --string "Linksys/SPA942" --algo bm --to 65535 -j DROP
$IPT -A SIP -p udp -m udp -m string --string "pplsip" --algo bm --to 65535 -j DROP
$IPT -A SIP -p udp -m udp -m string --string "VoIP SIP v11.0.0" --algo bm --to 65535 -j DROP
$IPT -A SIP -p udp -m udp -j ACCEPT
#===========================================>> SIP <<=================================================

# разрешить установленные соединения
$IPT -A  INPUT -p all -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A  OUTPUT -p all -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A  FORWARD -p all -m state --state ESTABLISHED,RELATED -j ACCEPT

# Разрешить на локалхост
$IPT -A INPUT -i lo -j ACCEPT

# блокирование пакетов, которые не имеют статуса
$IPT -A INPUT -m state --state INVALID -j DROP
$IPT -A FORWARD -i $WAN -m state --state INVALID -j DROP

# блокирование нулевых пакетов
$IPT -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# блокирование syn-flood атак
$IPT -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
$IPT -A OUTPUT -p tcp ! --syn -m state --state NEW -j DROP

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>> PING <<~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# разрешить ping
# ответы ping
$IPT -A INPUT -p icmp --icmp-type echo-reply -j ACCEPT
# недоступность
$IPT -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
# привышение лимита времени
$IPT -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
# запросы ping
$IPT -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
#===========================================>> PING <<================================================

# досутп по ssh
$IPT -A INPUT -i $WAN -p tcp --dport 55022 -j ACCEPT

# SIP
$IPT -A INPUT -i $WAN -p udp -m udp --dport 5060:5069 -j SIP
# RTSP
$IPT -A INPUT -i $WAN -p udp -m udp --dport 10000:20000 -j ACCEPT

# приложение nodejs
$IPT -A INPUT -i $WAN -p tcp -m tcp --dport 9000 -j ACCEPT

# доступ web. nginx
$IPT -A INPUT -i $WAN -p tcp --dport 80 -j ACCEPT
$IPT -A INPUT -i $WAN -p tcp --dport 443 -j ACCEPT


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~>> Сохранить правила <<~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

iptables-save > /etc/sysconfig/iptables

#change ssh port
sed -i 's/#Port 22/Port 55022/' /etc/ssh/sshd_config && systemctl restart sshd

/sbin/reboot
