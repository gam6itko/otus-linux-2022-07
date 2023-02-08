#!/bin/bash

ssh-keygen -b 2048 -t rsa -f /home/vagrant/.ssh/id_rsa -q -N ""
cat /home/vagrant/.ssh/id_rsa.pub > /vagrant/client_ssh.pub
chown -R vagrant:vagrant /home/vagrant/.ssh

cp /vagrant/system/* /etc/systemd/system/

