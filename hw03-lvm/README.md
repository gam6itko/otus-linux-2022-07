# stands-03-lvm

## задание

- уменьшить том под / до 8G
- выделить том под /home
- для /home - сделать том для снэпшотов
- выделить том под /var (/var - сделать в mirror)
- прописать монтирование в fstab (попробовать с разными опциями и разными файловыми системами на выбор)
- Работа со снапшотами:
  - сгенерировать файлы в /home/
  - снять снэпшот
  - удалить часть файлов
  - восстановиться со снэпшота (залоггировать работу можно утилитой script, скриншотами и т.п.)
  - на нашей куче дисков попробовать поставить btrfs/zfs: с кешем и снэпшотами разметить здесь каталог /opt


## Ход выполнения ДЗ по LVM

`vagrant up` выдаёт ошибку

Получил ошибку
```
The IP address configured for the host-only network is not within the
allowed ranges. Please update the address used to be within the allowed
ranges and run the command again.

  Address: 192.168.11.101
  Ranges: 192.168.56.0/21

Valid ranges can be modified in the /etc/vbox/networks.conf file. For
more information including valid format see:
```

Чтобы починить коментируем строчку `box.vm.network "private_network", ip: boxconfig[:ip_addr]`.
Эти ip адреса явно писались не для моеё настройки сети.

При запуске `vagrant up` новая ошибка.
```
A customization command failed:

["createhd", "--filename", "/home/gam6itko/VirtualBox VMs/sata1.vdi", "--variant", "Fixed", "--size", 10240]

The following error was experienced:

#<Vagrant::Errors::VBoxManageError: There was an error while executing `VBoxManage`, a CLI used by Vagrant
for controlling VirtualBox. The command and stderr is shown below.

Command: ["createhd", "--filename", "/home/gam6itko/VirtualBox VMs/sata1.vdi", "--variant", "Fixed", "--size", "10240"]

Stderr: 0%...
Progress state: VBOX_E_FILE_ERROR
VBoxManage: error: Failed to create medium
VBoxManage: error: Could not create the medium storage unit '/home/gam6itko/VirtualBox VMs/sata1.vdi'.
VBoxManage: error: VDI: disk would overflow creating image '/home/gam6itko/VirtualBox VMs/sata1.vdi' (VERR_DISK_FULL).
VBoxManage: error: VDI: setting image size failed for '/home/gam6itko/VirtualBox VMs/sata1.vdi' (VERR_DISK_FULL)
VBoxManage: error: Details: code VBOX_E_FILE_ERROR (0x80bb0004), component MediumWrap, interface IMedium
VBoxManage: error: Context: "RTEXITCODE handleCreateMedium(HandlerArg*)" at line 510 of file VBoxManageDisk.cpp
>

Please fix this customization and try again.
```

Судя по всему в моей директории `/home` не достаточно места чтобы создать виртуальные диски.
```
# df -h | grep /home
/dev/sda1        96G   85G  6,3G  94% /home
```

С помощью команды `du -h -d 1 /home` вычисляем что занимает много места и что можно удалить.
Оказалочь, что много занимают места виртуальные машины с прошлых ДЗ. 
Удалим их.
Запустим снова `vagrant up`, наша VM успешно запустилась.


## Проверка окружения

Заходим в VM и ставим нужный пакет `yum install -y lvm2`

lsblk показывает следующее
```
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk 
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk 
```
Видим что раздел `/` установлен на lvm.

Судя по выводу ниже мы можем понять, что у нас 2 логических раздела поверх volume group 0
```
# pvs
  PV         VG         Fmt  Attr PSize   PFree
  /dev/sda3  VolGroup00 lvm2 a--  <38.97g    0 
# vgs
  VG         #PV #LV #SN Attr   VSize   VFree
  VolGroup00   1   2   0 wz--n- <38.97g    0 
# lvs
  LV       VG         Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  LogVol00 VolGroup00 -wi-ao---- <37.47g                                                    
  LogVol01 VolGroup00 -wi-ao----   1.50g                                                    
[root@lvm ~]# 
```

## уменьшение / до 8gb

В методичке в конце есть разбор ДЗ. Будем делать по нему.
Ставим пакет `xfsdump`

```
# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.
# vgcreate vg_root /dev/sdb
  Volume group "vg_root" successfully created
# lvcreate -n lv_root -L 8GB /dev/vg_root
  Logical volume "lv_root" created.
```
Создадим на нем файловую систему и смонтируем его, чтобы перенести туда данные
```
# mkfs.xfs /dev/vg_root/lv_root
meta-data=/dev/vg_root/lv_root   isize=512    agcount=4, agsize=655104 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2620416, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

# mount /dev/vg_root/lv_root /mnt
```

Скопируем все данные с `/` раздела в `/mnt`
```
# xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
# ls /mnt
bin   dev  home  lib64  mnt  proc  run   srv  tmp  vagrant
boot  etc  lib   media  opt  root  sbin  sys  usr  var
```

Переконфигурируем grub для того, чтобы при старте система грузилась с другого диска.
```
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt 
grub2-mkconfig -o /boot/grub2/grub.cfg
cd /boot; for i in `ls initramfs-*img`; do dracut -v $i `echo $i | sed "s/initramfs-//g; s/.img//g"` --force; done
```

Меняем в файле `/boot/grub2/grub.cfg` диск с которого будет загрузаться сестема.

```
sed -i 's/rd.lvm.lv=VolGroup00\/LogVol01/rd.lvm.lv=vg_root\/lv_root/' /boot/grub2/grub.cfg
```

Перезагружаем машину и держим скрещенными пальцы.
Пытаемся зайти на VM `vagrant ssh` и посмотреть ситуацию с блочными устроуствами
```
[vagrant@lvm ~]$ lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
├─sda1                    8:1    0    1M  0 part
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part
├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  
└─VolGroup00-LogVol01 253:2    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk
└─vg_root-lv_root       253:1    0    8G  0 lvm  /
sdc                       8:32   0    2G  0 disk
sdd                       8:48   0    1G  0 disk
sde                       8:64   0    1G  0 disk 
```
Мы перенесли корневой каталог на логический диск в 8GB. 🥳


### Изменяем  размер старой VG и вернуть на него `/` каталог.
```
## удаляем
lvremove /dev/VolGroup00/LogVol00
## создаём новый раздел на 8GB
lvcreate -y -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
## делаем опять операции по переносу
mkfs.xfs /dev/VolGroup00/LogVol00
mount /dev/VolGroup00/LogVol00 /mnt
xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt/
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
```
В файле `/boot/grub2/grub.cfg` ничего менять не надо.

Перезагружаемся.
Заходим в VM и смотрим конфигурацию блочных устройств.

```
# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00 253:0    0    8G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk 
└─vg_root-lv_root       253:2    0    8G  0 lvm  
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk 
```

Можно удалить временный логический том и группу.
```
lvremove /dev/mapper/vg_root-lv_root
vgremove vg_root
```


## выделить том под /home

Тут всё проще чем в предыдущем задании. 
С прошлого раза у нас остался PV на /dev/sdb, будем использовать его, а еще лучше добавим еще один и объединим в VG, ведь для /home нужно много места.
```
# pvcreate /dev/sde
  Physical volume "/dev/sde" successfully created.
# vgcreate vg_home /dev/sdb /dev/sde
  Volume group "vg_home" successfully created
 
# lvcreate -n lv_home -l +10%FREE /dev/vg_home
WARNING: xfs signature detected on /dev/vg_home/lv_home at offset 0. Wipe it? [y/n]: y
  Wiping xfs signature on /dev/vg_home/lv_home.
  Logical volume "lv_home" created.

# mkfs.xfs /dev/mapper/vg_home-lv_home
meta-data=/dev/mapper/vg_home-lv_home isize=512    agcount=4, agsize=720384 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2881536, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

# mount /dev/mapper/vg_home-lv_home /mnt/
# cp -aR /home/* /mnt/
# rm -rf /home/*
# umount /mnt
# mount /dev/mapper/vg_home-lv_home /home/
```

Правим fstab для автоматического монтирования `/home`
```
echo "`blkid | grep home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab
```
> В методичке содержится ошибка `home` должен быть написан с маленькой буквы, а не как в методичке
> Из-за этого при перезагрузке ВМ может не работать `vagrant ssh`  

Перезагрузим и проверим всё ли работает.


# для /home - сделать том для снэпшотов 

Сгенерируем файлы в /home/:
```
touch /home/vagrant/file{1..20}
```
Делаем snapshot 
```
lvcreate -l 10%FREE -s -n lv_home_snap /dev/mapper/vg_home-lv_home
```
Вывод lsblk
```
# lsblk
NAME                       MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                          8:0    0   40G  0 disk 
├─sda1                       8:1    0    1M  0 part 
├─sda2                       8:2    0    1G  0 part /boot
└─sda3                       8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00    253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01    253:1    0  1.5G  0 lvm  [SWAP]
sdb                          8:16   0   10G  0 disk 
├─vg_home-lv_home-real     253:3    0  1.1G  0 lvm  
│ ├─vg_home-lv_home        253:2    0  1.1G  0 lvm  
│ └─vg_home-lv_home_snap   253:5    0  1.1G  0 lvm  
└─vg_home-lv_home_snap-cow 253:4    0 1012M  0 lvm  
  └─vg_home-lv_home_snap   253:5    0  1.1G  0 lvm  
sdc                          8:32   0    2G  0 disk 
sdd                          8:48   0    1G  0 disk 
sde                          8:64   0    1G  0 disk 
```
Появился некий незнакомый раздел `vg_home-lv_home_snap-cow` и ожидаемый `vg_home-lv_home_snap`

Удалим састь файлов `rm -f /home/vagrant/file{11-20}`.
Файлы которые присутствуют в папке.
```
# ls -l /home/vagrant/
total 0
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file1
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file10
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file11
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file12
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file13
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file14
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file15
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file16
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file17
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file18
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file19
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file2
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file20
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file3
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file4
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file5
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file6
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file7
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file8
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file9
```

Восстановим файлы из снапшота
```
# umount /home
# lvconvert --merge /dev/mapper/vg_home-lv_home_snap
  Merging of volume vg_home/lv_home_snap started.
  vg_home/lv_home: Merged: 100.00%
# mount /dev/mapper/vg_home-lv_home /home
```

Првоеряем файлы в папке.
```
# ls -l /home/vagrant/
total 0
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file1
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file10
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file11
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file12
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file13
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file14
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file15
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file16
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file17
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file18
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file19
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file2
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file20
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file3
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file4
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file5
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file6
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file7
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file8
-rw-rw-r--. 1 vagrant vagrant 0 Aug 14 11:48 file9
```
Как мы видим, файлы file11-file20 были восстановлены.


## выделить том под /var (/var - сделать в mirror)

Как я понял под `mirror` тут понимается RAID.
Логический том нужно делать с опцией `-m1`.
На свободных дисках создаем зеркало

```
# pvcreate /dev/sd{c,d}
  Physical volume "/dev/sdc" successfully created.
  Physical volume "/dev/sdd" successfully created.
# vgcreate vg_var /dev/sd{c,d}
  Volume group "vg_var" successfully created
# lvcreate -L 950M -m1 -n lv_var vg_var
  Rounding up size to full physical extent 952.00 MiB
  Logical volume "lv_var" created.
```

Создаём файловую систему
```
# mkfs.ext4 /dev/mapper/vg_var-lv_var
mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=4096 (log=2)
Fragment size=4096 (log=2)
Stride=0 blocks, Stripe width=0 blocks
60928 inodes, 243712 blocks
12185 blocks (5.00%) reserved for the super user
First data block=0
Maximum filesystem blocks=249561088
8 block groups
32768 blocks per group, 32768 fragments per group
7616 inodes per group
Superblock backups stored on blocks: 
        32768, 98304, 163840, 229376

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done
```

Монтируем
```
mount /dev/mapper/vg_var-lv_var /mnt
cp -aR /var/* /mnt/
umount /mnt
mount /dev/mapper/vg_var-lv_var /var
```

Правим fstab для автоматического монтирования /var:
```
echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
```

Вывод lsblk
```
# lsblk
NAME                     MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                        8:0    0   40G  0 disk 
├─sda1                     8:1    0    1M  0 part 
├─sda2                     8:2    0    1G  0 part /boot
└─sda3                     8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00  253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01  253:1    0  1.5G  0 lvm  [SWAP]
sdb                        8:16   0   10G  0 disk 
└─vg_home-lv_home        253:2    0  1.1G  0 lvm  /home
sdc                        8:32   0    2G  0 disk 
├─vg_var-lv_var_rmeta_0  253:3    0    4M  0 lvm  
│ └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0 253:4    0  952M  0 lvm  
  └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
sdd                        8:48   0    1G  0 disk 
├─vg_var-lv_var_rmeta_1  253:5    0    4M  0 lvm  
│ └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1 253:6    0  952M  0 lvm  
  └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
sde                        8:64   0    1G  0 disk
```

Перезагружаем и убеждаемся что всё работет.

## на нашей куче дисков попробовать поставить btrfs/zfs: с кешем и снэпшотами разметить здесь каталог /opt

это задание не сделано.
