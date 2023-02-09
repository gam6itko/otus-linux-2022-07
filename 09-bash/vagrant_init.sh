#!/bin/bash

dnf install -yq nginx sendmail

mkdir /var/lib/ws_status
mkdir /var/log/ws_status

cp /vagrant/opt/ws_status.sh /opt/

mkdir /var/log/nginx/default.d
cp /vagrant/etc/nginx/conf.d/* /etc/nginx/conf.d/
cp /vagrant/etc/nginx/default.d/* /etc/nginx/default.d/

cp /vagrant/etc/systemd/system/ws_status.* /etc/systemd/system/
cp /vagrant/etc/sysconfig/ws_status.conf /etc/sysconfig/

cp /vagrant/var/lib/ws_status/* /var/lib/ws_status/

systemctl start nginx
systemctl enable nginx
systemctl start sendmail
systemctl enable sendmail

systemctl start ws_status.timer
systemctl enable ws_status.timer

# делаем первый запуск сервиса, от которого будет отсчитываться таймер
systemctl start ws_status.service
