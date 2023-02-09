#!/bin/bash

# создаём пользователя borg
useradd -m borg

# монтируем отдельный диск под бэкапы
mkdir -p /mnt/backup
mkfs.ext4 /dev/sdc
mount /dev/sdc /mnt/backup
chown borg:borg /mnt/backup
echo "`blkid | grep "/dev/sdc:" | awk '{print $2}'` /mnt/backup ext4 defaults 0 0" >> /etc/fstab
# удаляем мусор чтобы бэкапы записывались
rm -rf /mnt/backup/*

# добавляем ssh ключи
mkdir -p /home/borg/.ssh
touch /home/borg/.ssh/authorized_keys
chown -R borg:borg /home/borg
chmod 700 /home/borg/.ssh
chmod 600 /home/borg/.ssh/authorized_keys

if [[ -f /vagrant/client_ssh.pub ]]; then
  cat /vagrant/client_ssh.pub > /home/borg/.ssh/authorized_keys
fi

