#/bin/sh

echo "yum repo register"
cp /vagrant/yum.repos.d/my.repo /etc/yum.repos.d/
dnf repolist enabled
echo "install from my repo"
dnf install -y --repo myrepo php
/usr/local/bin/php -v
