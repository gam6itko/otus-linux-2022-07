#!/bin/bash

useradd adam
echo "1234" | sudo passwd --stdin adam

useradd bob
echo "1234" | sudo passwd --stdin bob

useradd carl
echo "1234" | sudo passwd --stdin bob

# добавляем уже существующего пользователя в группу admin
groupadd admin
usermod -a -G admin adam
usermod -a -G admin carl
usermod -a -G admin vagrant

cp /vagrant/in_admin_group.sh /usr/local/bin/in_admin_group.sh
chmod a+rwx /usr/local/bin/in_admin_group.sh

sed -i 's/account    required     pam_nologin.so/account    required     pam_nologin.so\naccount    [success=1 default=ignore] pam_exec.so debug log=\/tmp\/pam_exec.log \/usr\/local\/bin\/in_admin_group.sh\naccount    required     pam_time.so/'

echo "*;*;!admin;!Wd0000-2400" >> /etc/security/time.conf

# polkit
cp /vagrant/polkit/10-podman.rules /etc/polkit-1/rules.d/10-podman.rules
