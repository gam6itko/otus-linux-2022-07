# ДЗ 2 - Дисковая подсистема

Virtualbox 6.1
Vagrant 2.2.19

## Задание

Работа с mdadm

- добавить в Vagrantfile еще дисков;
- сломать/починить raid;
- собрать R0/R5/R10 на выбор;
- прописать собранный рейд в конф, чтобы рейд собирался при загрузке;
- создать GPT раздел и 5 партиций.
- В качестве проверки принимаются - измененный Vagrantfile, скрипт для создания рейда, конф для автосборки рейда при загрузке.
- доп. задание - Vagrantfile, который сразу собирает систему с подключенным рейдом и смонтированными разделами. После перезагрузки стенда разделы должны автоматически примонтироваться.
  - перенести работающую систему с одним диском на RAID 1. Даунтайм на загрузку с нового диска предполагается. В качестве проверки принимается вывод команды lsblk до и после и описание хода решения (можно воспользоваться утилитой Script).


## выполнение

Для начала запустим VPN чтобы скачать box с almalinux. Box скачивался у меня 2 часа.

После запуска `vagrant up` сразу получил сообщение об ошибке.
```
The IP address configured for the host-only network is not within the
allowed ranges. Please update the address used to be within the allowed
ranges and run the command again.

  Address: 10.0.0.41
  Ranges: 192.168.56.0/21

Valid ranges can be modified in the /etc/vbox/networks.conf file. For
more information including valid format see:

  https://www.virtualbox.org/manual/ch06.html#network_hostonly
```

Решил тем что закоментировал строку
```
server.vm.network :private_network, ip: "10.0.0.41"
```

Новая ошибка
```
There was an error while executing `VBoxManage`, a CLI used by Vagrant
for controlling VirtualBox. The command and stderr is shown below.

Command: ["startvm", "f2ffd579-373a-4fb5-85ba-8fe877264aaf", "--type", "headless"]

Stderr: VBoxManage: error: A virtual device is configured in the VM settings but the device implementation is missing.
VBoxManage: error: A possible reason for this error is a missing extension pack. Note that as of VirtualBox 4.0, certain features (for example USB 2.0 support and remote desktop) are only available from an 'extension pack' which must be downloaded and installed separately (VERR_PDM_DEVICE_NOT_FOUND)
VBoxManage: error: Details: code NS_ERROR_FAILURE (0x80004005), component ConsoleWrap, interface IConsole
```

Оказалось что нужно установить для Virtualbox Extension Pack. 
Качаем отсюда <https://www.virtualbox.org/wiki/Downloads> и устанасливает.
`vagrant up` завершился удачно

```shell
vagrant ssh
lsblk
```
lsblk показывает что у нас есть 7 sata (sda-sdg) и 5 nvme устройств (nvme0n1-nvme0n5)
```
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda       8:0    0 19.5G  0 disk 
|-sda1    8:1    0    2G  0 part [SWAP]
`-sda2    8:2    0 17.6G  0 part /
sdb       8:16   0    1G  0 disk 
sdc       8:32   0    1G  0 disk 
sdd       8:48   0    1G  0 disk 
sde       8:64   0    1G  0 disk 
sdf       8:80   0    1G  0 disk 
sdg       8:96   0    1G  0 disk 
nvme0n1 259:0    0    1G  0 disk 
nvme0n2 259:1    0    1G  0 disk 
nvme0n3 259:2    0    1G  0 disk 
nvme0n4 259:3    0    1G  0 disk 
nvme0n5 259:4    0    1G  0 disk 
```


### добавление в vagrantfile еще дисков

Чтобы сделать это нужно найти строчки
```
disks = (0..4).map { |x| ["nvmedisk#{x}", '1024'] }
disks = (1..6).map { |x| ["disk#{x}", '1024'] }
```
и увеличить количество итераций
```
disks = (0..6).map { |x| ["nvmedisk#{x}", '1024'] }
disks = (1..8).map { |x| ["disk#{x}", '1024'] }
```

Перезапускаем машину 
```
vagrant reload
vagrant ssh
lsblk
```

Видим что добавились новые устройства (sdh,sdi,nvme0n6,nvme0n7)
```
# lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda       8:0    0 19.5G  0 disk 
|-sda1    8:1    0    2G  0 part [SWAP]
`-sda2    8:2    0 17.6G  0 part /
sdb       8:16   0    1G  0 disk 
sdc       8:32   0    1G  0 disk 
sdd       8:48   0    1G  0 disk 
sde       8:64   0    1G  0 disk 
sdf       8:80   0    1G  0 disk 
sdg       8:96   0    1G  0 disk 
sdh       8:112  0    1G  0 disk 
sdi       8:128  0    1G  0 disk 
nvme0n1 259:0    0    1G  0 disk 
nvme0n2 259:1    0    1G  0 disk 
nvme0n3 259:2    0    1G  0 disk 
nvme0n4 259:3    0    1G  0 disk 
nvme0n5 259:4    0    1G  0 disk 
nvme0n6 259:5    0    1G  0 disk 
nvme0n7 259:6    0    1G  0 disk 
```


## создание RAID0

ставим утилиту `mdadm` - `sudo yum install -y mdadm`

Создаём raid1
```shell
mdadm --create --verbose /dev/md/raid0 --level=0 --raid-devices=2 /dev/sdb /dev/sdc
```
Raid1 присутствует
```
# cat /proc/mdstat

Personalities : [raid0] 
md127 : active raid0 sdc[1] sdb[0]
      2093056 blocks super 1.2 512k chunks
      
unused devices: <none>
```
Мы видим что появилось устройство `md127`
```
# lsblk

NAME        MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINT
sda           8:0    0 19.5G  0 disk  
|-sda1        8:1    0    2G  0 part  [SWAP]
`-sda2        8:2    0 17.6G  0 part  /
sdb           8:16   0    1G  0 disk  
`-md127       9:127  0    2G  0 raid0 
sdc           8:32   0    1G  0 disk  
`-md127       9:127  0    2G  0 raid0 
sdd           8:48   0    1G  0 disk  
sde           8:64   0    1G  0 disk  
sdf           8:80   0    1G  0 disk  
sdg           8:96   0    1G  0 disk  
sdh           8:112  0    1G  0 disk  
sdi           8:128  0    1G  0 disk  
nvme0n1     259:0    0    1G  0 disk  
|-nvme0n1p1 259:1    0   50M  0 part  
`-nvme0n1p2 259:2    0  100M  0 part  
nvme0n2     259:3    0    1G  0 disk  
|-nvme0n2p1 259:4    0   50M  0 part  
`-nvme0n2p2 259:5    0   16M  0 part  
nvme0n3     259:6    0    1G  0 disk  
|-nvme0n3p1 259:7    0   10M  0 part  
|-nvme0n3p2 259:8    0   10M  0 part  
`-nvme0n3p5 259:9    0   10M  0 part  
nvme0n4     259:10   0    1G  0 disk  
nvme0n5     259:11   0    1G  0 disk  
nvme0n6     259:12   0    1G  0 disk  
nvme0n7     259:13   0    1G  0 disk 
```

Перезагрузим систему и убедимся что raid1 соберётся автоматически.
```shell
reboot
#...
vagrant ssh
cat /proc/mdstat
```

```
# cat /proc/mdstat

Personalities : [raid1] 
md127 : active raid1 sdc[1] sdb[0]
      1046528 blocks super 1.2 [2/2] [UU]
      
unused devices: <none>
```
Изменять никакой конфиг не пришлось, raid0 собирается по-умолчанию


## Сломать\починить RAID

Ломаем
```shell
mdadm /dev/md/raid0 --fail /dev/sdb
```
```
mdadm: set /dev/sdb faulty in /dev/md/raid0
```

Это странно, но команда --fail не может примениться к raid0. Вывод команды `cat /proc/mdstat` никак не изменился.
Попробуем сделать на raid1

```shell
mdadm --create --verbose /dev/md/raid1 --level=1 --raid-devices=2 /dev/sde /dev/sdd
mdadm /dev/md/raid1 --fail /dev/sde
# mdadm: set /dev/sde faulty in /dev/md/raid1
cat /proc/mdstat
```

Вывод `cat /proc/mdstat` показывает что в raid1 один диск помер, на что указывает `sde[0](F)`.
```
# cat /proc/mdstat
Personalities : [raid0] [raid1] 
md126 : active raid1 sdd[1] sde[0](F)
      1046528 blocks super 1.2 [2/1] [_U]
      
md127 : active raid0 sdb[0] sdc[1]
      2093056 blocks super 1.2 512k chunks
      
unused devices: <none>
```

Чини raid1 путём добавления нового диска
```shell
mdadm /dev/md/raid1 --add /dev/sdf --remove sde
```
```
mdadm: added /dev/sdf
mdadm: hot removed sde from /dev/md/raid1
```

`cat /proc/mdstat` говорит что raid1 работает исправно ([UU]).
```
# cat /proc/mdstat

Personalities : [raid0] [raid1] 
md126 : active raid1 sdf[2] sdd[1]
      1046528 blocks super 1.2 [2/2] [UU]
      
md127 : active raid0 sdb[0] sdc[1]
      2093056 blocks super 1.2 512k chunks
      
unused devices: <none>
```
 
Чтобы удали все raid-массивы запустим команду
```shell
mdadm --stop /dev/md/raid0 --stop /dev/md/raid1
mdadm --zero-superblock /dev/sdb /dev/sdc /dev/sde
```

## создать GPT раздел и 5 партиций.

Мне больше нравится создавать разделы  интерактивно коммандой `gdisk`.
В рамках ДЗ сделаем это одной командой.

```shell
parted -s /dev/nvme0n7 mklabel gpt \
  mkpart primary ext2 2048s 100M \
  mkpart primary ext3 100M 200MiB \
  mkpart primary ext4 200MiB 300MiB \
  mkpart primary ext4 300MiB 400MiB \
  mkpart primary ext4 400MiB 100%
```

```
# lsblk

NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda           8:0    0 19.5G  0 disk 
|-sda1        8:1    0    2G  0 part [SWAP]
`-sda2        8:2    0 17.6G  0 part /
sdb           8:16   0    1G  0 disk 
sdc           8:32   0    1G  0 disk 
sdd           8:48   0    1G  0 disk 
sde           8:64   0    1G  0 disk 
sdf           8:80   0    1G  0 disk 
sdg           8:96   0    1G  0 disk 
sdh           8:112  0    1G  0 disk 
sdi           8:128  0    1G  0 disk 
nvme0n1     259:0    0    1G  0 disk 
nvme0n2     259:3    0    1G  0 disk 
nvme0n3     259:6    0    1G  0 disk 
nvme0n4     259:10   0    1G  0 disk 
nvme0n5     259:11   0    1G  0 disk 
nvme0n6     259:12   0    1G  0 disk 
nvme0n7     259:13   0    1G  0 disk 
|-nvme0n7p1 259:1    0   94M  0 part 
|-nvme0n7p2 259:2    0  105M  0 part 
|-nvme0n7p3 259:4    0  100M  0 part 
|-nvme0n7p4 259:5    0  100M  0 part 
`-nvme0n7p5 259:7    0  623M  0 part 
```
