#!/bin/bash

cp /vagrant/wl/watchlog.conf /etc/sysconfig/

cp /vagrant/wl/watchlog.sh /opt/
chmod a+x /opt/watchlog.sh
cp /vagrant/etc/systemd/system/watchlog.{service,timer}  /etc/systemd/system/

systemctl start watchlog.timer

touch /var/log/watchlog.log
echo "ALERT! This is OTUS home work test!" >> /var/log/watchlog.log

# 2

dnf install -yq epel-release
dnf install -yq spawn-fcgi php php-cli mod_fcgid

cp /vagrant/etc/systemd/system/spawn-fcgi.service  /etc/systemd/system/

sed -i 's/#SOCKET/SOCKET/' /etc/sysconfig/spawn-fcgi
sed -i 's/#OPTIONS/OPTIONS/' /etc/sysconfig/spawn-fcgi

systemctl start spawn-fcgi.service
systemctl status spawn-fcgi.service

# 3
systemctl disable httpd

rm /usr/lib/systemd/system/httpd@.service
cp /vagrant/etc/sysconfig/httpd-{first,second} /etc/sysconfig/
cp /vagrant/etc/systemd/system/httpd@.service /etc/systemd/system/
# duplicate apache config with modifications
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
echo -e 'PidFile /var/run/httpd-first.pid\nServerName first.local' >> /etc/httpd/conf/first.conf
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
echo -e 'PidFile /var/run/httpd-second.pid\nServerName second.local' >> /etc/httpd/conf/second.conf
sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/second.conf
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.backup

systemctl daemon-reload
systemctl start httpd@first.service
systemctl start httpd@second.service

systemctl status httpd@first.service
systemctl status httpd@second.service

