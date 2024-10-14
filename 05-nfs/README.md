# NFS

## Задание

- vagrant up должен поднимать 2 виртуалки: сервер и клиент;
- на сервер должна быть расшарена директория;
- на клиента она должна автоматически монтироваться при старте (fstab или autofs);
- в шаре должна быть папка upload с правами на запись;
- требования для NFS: NFSv3 по UDP, включенный firewall.
- Настроить аутентификацию через KERBEROS (NFSv4)

## Решение

Полезная информаци которая помогла:
- https://www.youtube.com/watch?v=VZIcAY7oyjs&ab_channel=Unixway
- https://man7.org/linux/man-pages/man5/nfs.conf.5.html
- https://www.vagrantup.com/docs/providers/virtualbox/networking
- https://www.thegeekdiary.com/common-nfs-mount-options-in-linux/
- https://help.ubuntu.com/community/NFSv4Howto

Скопируем Vagrantfile из <https://github.com/nixuser/virtlab/tree/main/nfs_server>.

В файле были сделаны изменения. Для обоих машиш настройка сети выглядит так `server.vm.network :private_network, type: "dhcp"`

### Убеждаемся что сервис nfs установлен и запущен

Проверяем установлен пакет.
```shell
yum list nfs-utils
```

Если не установлен, то ставим.
```shell
yum install -y nfs-utils
```

Проверяем что сервис `nfs-server` запущен.
```
# systemctl status nfs-server
● nfs-server.service - NFS server and services
   Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; disabled; vendor preset: disabled)
   Active: inactive (dead)
```
Сервис не запущен.

Запускаем сервер NFS
```shell
systemctl start nfs-server
systemctl enable nfs-server
```

```
# systemctl status nfs-server
● nfs-server.service - NFS server and services
   Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; disabled; vendor preset: disabled)
   Active: active (exited) since Tue 2022-08-23 11:51:40 UTC; 3s ago
  Process: 4016 ExecStart=/bin/sh -c if systemctl -q is-active gssproxy; then systemctl reload gssproxy ; fi (code=exited, status=0/SUCCESS)
  Process: 4004 ExecStart=/usr/sbin/rpc.nfsd (code=exited, status=0/SUCCESS)
  Process: 4003 ExecStartPre=/usr/sbin/exportfs -r (code=exited, status=0/SUCCESS)
 Main PID: 4016 (code=exited, status=0/SUCCESS)

Aug 23 11:51:39 server systemd[1]: Starting NFS server and services...
Aug 23 11:51:40 server systemd[1]: Started NFS server and services.
```

Сервис запущен. Можно двагаться дальше.


### Расшарим дирректорию на сервере

```shell
vagrant up
vagrant ssh server
mkdir /var/nfs_share
touch /var/nfs_share/test_nfs_server.txt
echo "/var/nfs_share/  *(rw)" > /etc/exports
exportfs -r
```

```
# exportfs -rav
exporting *:/var/nfs_share

# exportfs -s
/var/nfs_share  *(sync,wdelay,hide,no_subtree_check,sec=sys,rw,root_squash,no_all_squash)

# showmount -e
Export list for server:
/var/nfs_share *
```

С помощью команды `ip addr` узнаем ip

```
# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:7a:1d:b8 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic noprefixroute enp0s3
       valid_lft 86367sec preferred_lft 86367sec
    inet6 fe80::a00:27ff:fe7a:1db8/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
3: enp0s8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:2f:a8:4e brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.3/24 brd 192.168.56.255 scope global dynamic noprefixroute enp0s8
       valid_lft 567sec preferred_lft 567sec
    inet6 fe80::a00:27ff:fe2f:a84e/64 scope link 
       valid_lft forever preferred_lft forever

```

Ip сервера: 10.0.2.15

#### Пытыемся подключиться на клиенте к расшаренной папке

```shell
vagrant ssh client
```

Устанавливаем нужные пакеты
```shell
yum install nfs-utils
mkdir /mnt/nfs_share
```

Проверим какие папки доступны для подключения на клиенте.
```
# showmount --exports 192.168.56.3
Export list for 192.168.56.3:
/var/nfs_share *
```

Примонтируем диннекторию:
```shell
mount -t nfs 192.168.56.3:/var/nfs_share /mnt/nfs_share/
```

Проверяем что у нас теперь в папке `/mnt/nfs_share/`:
```
# ls /mnt/nfs_share/
test_nfs_server.txt
```

Мы видим файл `test_nfs_server.txt` а это значит что монтирование папки сервера через NFS просло успешно.


#### Добавить на клиенте автомонтирование папки сервера

Изменим файл `/etc/fstab` и перезагрузим стобы проверить:
```shell
echo "192.168.56.3:/var/nfs_share /mnt/nfs_share nfs defaults 0 0" >> /etc/fstab
reboot
```

Проверяем:
```shell
vagrant ssh client
# ...
ls /mnt/nfs_share/
```

Файл отобразился, значит мы успешно примонтировали серверную папку при старте клиента
```
# ls /mnt/nfs_share/
test_nfs_server.txt
```

### В шаре должна быть папка upload с правами на запись

На сервере добавим папку `/var/nfs_share/upload`
```shell
mkdir /var/nfs_share/upload
```

На клиенте попробуем записать в эту папку что-нибудь
```
# ls /mnt/nfs_share/
test_nfs_server.txt  upload
# touch /mnt/nfs_share/upload/file_from_client.txt
touch: cannot touch '/mnt/nfs_share/upload/file_from_client.txt': Permission denied
```
Как видим, запись нам не разрешена. Значит на сервере нужно что-то подкрутить.

На сервере выполняем команду `chmod a+rw /var/nfs_share/upload/`

На клиенте пытаемся записать файл ещё раз.
```
[root@client ~]# touch /mnt/nfs_share/upload/file_from_client.txt
[root@client ~]# ls -l /mnt/nfs_share/upload/
total 0
-rw-r--r--. 1 nobody nobody 0 Aug 23 13:08 file_from_client.txt
```
Файл успешно записан.


### Требования для NFS: NFSv3 по UDP, включенный firewall

На клиенте создадим новую папку и примонтируемся к ней по NFS v3
```shell
mkdir /mnt/nfs3_share/
mount -t nfs -o vers=3,udp -o proto=udp 192.168.56.3:/var/nfs_share /mnt/nfs3_share/
```

```
# mount -t nfs -o vers=3,udp 192.168.56.3:/var/nfs_share /mnt/nfs3_share/
mount.nfs: requested NFS version or transport protocol is not supported
```
На сервере нужно добавить потдержку udp.

На сервере.
Добавляем строчку `udp=y` в секцию [nfsd] файла `/etc/nfs.conf` и перезагружаем сервис `systemctl restart nfs-server`.

На клиенте пробуем подключиться снова.
```shell
mount -t nfs -o vers=3,udp 192.168.56.3:/var/nfs_share /mnt/nfs3_share/
```

Проверяем:
```
# ls -l /mnt/nfs3_share/
total 0
-rw-r--r--. 1 root root  0 Aug 23 11:48 test_nfs_server.txt
drwxrwxrwx. 2 root root 34 Aug 23 13:08 upload

# mount -t nfs
192.168.56.3:/var/nfs_share on /mnt/nfs3_share type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=192.168.56.3,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=192.168.56.3)
```
Судя по опциям `vers=3` и `proto=udp` папка `/mnt/nf3_share` работает по udp.


### Настроить аутентификацию через KERBEROS (NFSv4)


На сервере. 
Создадим новую директорию
```shell
mkdir /var/nfs_share_secure
touch /var/nfs_share_secure/all_my_passwords.txt
echo "/var/nfs_share_secure *(rw,sec=krb5)" > /etc/exports
exportfs -r
```

На клиенте:
```shell
mkdir /mnt/nfs_share_secure/
```

Пробуем примонтировать:
```
# mount -t nfs 192.168.56.3:/var/nfs_share_secure /mnt/nfs_share_secure/
mount.nfs: Operation not permitted
```
Похоже, что нам нужно правильно аутентифицироваться
