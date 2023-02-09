# Описание работы

## tl;dr;

Cсылка на box в vagrant cloud: <https://app.vagrantup.com/gam6itko/boxes/centos-7-5>

Задание со звездочкой *: Cсылка на box в vagrant cloud: <https://app.vagrantup.com/gam6itko/boxes/centos-7-5.19-src>

Ниже описан мной проделаннй путь для выполнения задания.

## подготовка

Host machine:

```shell
uname -srv
# Linux 5.15.0-43-generic #46-Ubuntu SMP Tue Jul 12 10:30:17 UTC 2022
```

- Поставил vagrant `apt install vagrant` (Vagrant 2.2.19)
- Форкнул репозиторий и запустил `vagrant up`

Возникла проблема

```
Error while connecting to Libvirt: Error making a connection to libvirt URI qemu:///system:
Call to virConnectOpen failed: Failed to connect socket to '/var/run/libvirt/libvirt-sock': No such file or directory
```

Нашёл статью <https://opensource.com/article/21/10/vagrant-libvirt>. Оказалось что нужно установить daemon и плагин

```shell
sudo apt install ruby-libvirt qemu libvirt-daemon-system libvirt-clients libvirt-dev
sudo systemctl start libvirtd
vagrant plugin install vagrant-libvirt
```

Не помогло.
Оказалось, что я просто не установил `virtualbox` 🤦

Установил `virtualbox`, сделал `vagrant up`. Не смог скачать образ `centos/7`.
Пришлось включить VPN. Образ начал скачиваться.

...

...

...

Скачивание образа через VPN заняло 2 часа 😢

## обновление ядра

Залогинился в виртуальную машину, скачал ядро, установил ядро.

Пришло время обновить grub. Но что-то мне незнакома магия с `grub2-mkconfig`, пошел ознакамливаться с документацией.
<https://linuxhint.com/grub2_mkconfig_tutorial/>

Команды с grub сделал, перезагрузил.

Ядро обновилось

```shell
vagrant ssh
uname -r
# 5.19.0-1.el7.elrepo.x86_64
```

## packer

всё прочитанное в методичке понятно, делаем образ

```shell
cd ./packer
packer build centos.json
```

Получил вывод ниже. Похоже на ошибку

```
Error: Failed to prepare build: "centos-7.7"

1 error occurred:
        * Deprecated configuration key: 'iso_checksum_type'. Please call `packer fix`
against your template to update your template to be compatible with the current
version of Packer. Visit https://www.packer.io/docs/commands/fix/ for more
detail.


==> Wait completed after 2 microseconds

==> Builds finished but no artifacts were created.

```

Из вывода следует что нужно починить конфиг.

```shell
packer fix centos.json > centos-fixed.json
packer build centos-fixed.json
```

После запуска сбоки появились зеленые строчки похожие на вывод vagrant'a.

Потом открылось GUI virtualbox с запущенной виртуальной машиной.

Похоже, скрипты из папки `./packer/scripts` начали выполняться.

...

Дождался финала

```
==> Wait completed after 10 minutes 32 seconds

==> Builds finished. The artifacts of successful builds are:
--> centos-7.7: 'virtualbox' provider box: centos-7.7.1908-kernel-5-x86_64-Minimal.box
```

Появился файл `./packer/centos-7.7.1908-kernel-5-x86_64-Minimal.box`

Как я понял, с помощью packer мы сделали то же самое что я делал руками в виртуальной машине.

## vagrant init (тестирование)

создал папку `test` в неё запустил:

```
vagrant init centos-7-5
vagrant up
```

произошла ошибка

```
Vagrant was unable to mount VirtualBox shared folders. This is usually
because the filesystem "vboxsf" is not available. This filesystem is
made available via the VirtualBox Guest Additions and kernel module.
Please verify that these guest additions are properly installed in the
guest. This is not a bug in Vagrant and is usually caused by a faulty
Vagrant box. For context, the command attempted was:

mount -t vboxsf -o uid=1000,gid=1000,_netdev vagrant /vagrant

The error output from the command was:

mount: unknown filesystem type 'vboxsf'
```

Попробуем починить, убрав synced_folder `config.vm.synced_folder ".", "/vagrant", disabled: true`

```shell
vagrant up
# проблем нет
vagrant ssh

uname -r
# 5.19.0-1.el7.elrepo.x86_64
```

Ядро в виртуальной машине оказалось даже новее чем то что в методичке (5.3.1-1.el7.elrepo.x86_64).

Выходим и удаляем box

```shell
vagrant box remove -f centos-7-5
# Removing box 'centos-7-5' (v0) with provider 'virtualbox'...
```

## vagrant cloud

Производим аутентификацию в vagrant cloud

```shell
vagrant cloud auth login -u gam6itko
```

ввёл пароль, появились какие-то ошибки

```
Vagrant Cloud request failed (VagrantCloud::Error::ClientError::RequestError)
```

Попробуем через VPN. Аутентификация прошла успешно.

Отправляем образ

```shell
vagrant cloud publish --release gam6itko/centos-7-5 1.0 virtualbox ./packer/centos-7.7.1908-kernel-5-x86_64-Minimal.box
```

Пишут что через VPN это займет около 3 часов 👀

После долгого ожидания, образ залился.

```
Complete! Published gam6itko/centos-7-5
Box:              gam6itko/centos-7-5
Description:      
Private:          yes
Created:          2022-08-03T11:16:22.295+03:00
Updated:          2022-08-03T11:16:26.873+03:00
Current Version:  N/A
Versions:         1.0
Downloads:        0
```

## ссылка на box в vagrant cloud

<https://app.vagrantup.com/gam6itko/boxes/centos-7-5>


# Задание со звездой (*)

## Установка ядра из исходников

Похоже, нам нужно создать еще одну виртуальную машину. Внесём изменения в существующий Vagrantfile
Выделим этой ВМ больше ядер и памяти, чтобы процесс был быстрее.

```
  :"kernel-update-src" => {
      :box_name => "centos/7",
      :cpus => 4,
      :memory => 4096,
      :net => [],
      :forwarded_port => []
  }
```

Заходим в машину. Теперь придётся указывать название машины т.к. у нас их несколько.

```
vagrant ssh kernel-update-src
uname -r
# 3.10.0-1127.el7.x86_64
```

Будем ставить ядро 5.19.

Идём на https://www.kernel.org/.
Напротив ядра 5.19 копируем адрес ссылки `tarrball`

### Попытка 1

```shell
sudo su
cd ~
# что за groupinstall, читаем тут: http://rus-linux.net/MyLDP/consol/yum.html
yum groupinstall "Development Tools"
# ставим нужные пакеты
yum install -y wget
# скачиваем архив с ядром
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.19.tar.xz
# Разархивируем
tar -xf linux-5.19.tar.xz
cd linux-5.6.11
# копируем конфиг из старого ядра
cp -v /boot/config-$(uname -r) .config
# Конвертируем старую конфигурацию
make olddefconfig
```

После запуска `make` у меня появилась ошибка

```
  HOSTCC  scripts/kconfig/conf.o
  HOSTLD  scripts/kconfig/conf
***
*** Compiler is too old.
***   Your GCC version:    4.8.5
***   Minimum GCC version: 5.1.0
***
scripts/Kconfig.include:44: Sorry, this compiler is not supported.
make[3]: *** [olddefconfig] Error 1
make[2]: *** [olddefconfig] Error 2
make[1]: *** [__build_one_by_one] Error 2
make: *** [__sub-make] Error 2
```

Похоже, что у меня gcc старой версии.

Руководствуясь статьёй <https://linuxize.com/post/how-to-install-gcc-compiler-on-centos-7/> обновляем gcc

```shell
sudo yum install -y centos-release-scl
sudo yum install -y devtoolset-7
scl enable devtoolset-7 bash
gcc -v
# gcc version 7.3.1 20180303 (Red Hat 7.3.1-5) (GCC)
```

### Попытка 2

Продолжаем собирать ядро

```shell
make olddefconfig
make
```

После вызова `make` оказалось что нет библиотек: gelf, openssl.
Ставим нужные библиотеки

```shell
yum install -y openssl-devel elfutils-devel
```

### Попытка 3

```shell
make
```

Ошибка '/bin/sh: bc: command not found'

Установим bc

```shell
yum install -y bc
```

### Попытка 4

```shell
make -j$(nproc)
# очень долго выводятся какие-то строчки
# ...
# AS      arch/x86/crypto/sha256_ni_asm.o
# AR      arch/x86/crypto/built-in.a
# AS [M]  arch/x86/crypto/twofish-x86_64-asm_64.o
# CC [M]  arch/x86/crypto/twofish_glue.o
# ...
# ещё сотни строчек
# ...
# ...
# ...
# надеюсь, это будет быстрее чем загрузка образа в vagrant cloud через VPN
# ...
# ...
# ...
# кажется, я начал понимать шутку про админа, который за день делает только 2 действия: собирает ядро и спит 
# ...
# a few moments later
# ...
# ОНО ЗАКОНЧИЛО ДЕЛАТЬСЯ!!!

# устанавливаем модули, вывод был не таким долгим
make modules_install -j$(nproc)
# запускаем то ради чего мы здесь сегодня собрались
make install -j$(nproc)
# в /boot появились файлы:
lrwxrwxrwx. 1 root root       20 авг  3 14:51 vmlinuz -> /boot/vmlinuz-5.19.0
-rw-r--r--. 1 root root  9759648 авг  3 14:51 vmlinuz-5.19.0
```

Теперь нужно это ядро включить

```shell
# обновляем grub
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-set-default 0
reboot
# ...
vagrant ssh
uname -r
# 5.19.0
uname -a
# Linux kernel-update-src 5.19.0 #1 SMP PREEMPT_DYNAMIC Wed Aug 3 13:49:08 UTC 2022 x86_64 x86_64 x86_64 GNU/Linux
```

МЫ ОБНОВИЛИ ЯДРО ДО 5.19.0 🥳

## Создание box из VM

Чтобы создать box, я не буду использовать packer, а сделаю средствами vagrant
```shell
vagrant package kernel-update-src --output centos-7-5.19-src.box
# регистируем box в локальном vagrant
vagrant box add --name centos-7-5.19-src ./centos-7-5.19-src.box
```

## Тестирование

В Vagrantfile добавим настройку для новой машины
```
  :"kernel-update-src-test" => {
      :box_name => "centos-7-5.19-src",
      :cpus => 1,
      :memory => 1024,
      :net => [],
      :forwarded_port => []
  }
```

Запускаем машину из созданного нами бокса
```shell
vagrant ssh kernel-update-src-test
# ...
uname -r
# 5.19.0
```

## Отправляем в vagrant cloud
```shell
vagrant cloud publish --release gam6itko/centos-7-5.19-src 1.0 virtualbox ./centos-7-5.19-src.box
```

В течение 2х часов мы загрузили образ на vagrant cloud 🥳


# Задание с двумя звездами (**)

Создаём vagrantfile
```
Vagrant.configure("2") do |config|
  config.vm.box = "centos-7-5.19-src"
  config.vm.synced_folder "./vagrant_data", "/vagrant_data"
end
```

Создадим новую папку и пару файлов.
```shell
mkdir shared_folder_ok
cd ./shared_folder_ok
mkdir ./vagrant_data
echo hello > ./vagrant_data/do_you_see_me.txt
# добавим Vagrantfile с образом сделаным ранее
vagrant up
```

После запуска `vagrant up` получил следующую ошибку.
```
Vagrant was unable to mount VirtualBox shared folders. This is usually
because the filesystem "vboxsf" is not available. This filesystem is
made available via the VirtualBox Guest Additions and kernel module.
Please verify that these guest additions are properly installed in the
guest. This is not a bug in Vagrant and is usually caused by a faulty
Vagrant box. For context, the command attempted was:

mount -t vboxsf -o uid=1000,gid=1000,_netdev vagrant_data /vagrant_data

The error output from the command was:

mount: unknown filesystem type 'vboxsf'
```

Немного изменим настройки sync_folder
```
Vagrant.configure("2") do |config|
  config.vm.box = "centos-7-5.19-src"
  config.vm.synced_folder "./vagrant_data", "/vagrant_data", type: 'nfs'
end
```

Запускаем еще раз

```shell
vagrant reload
# оно не упало
vagrant ssh
# ...
cat /vagrant_data/do_you_see_me.txt
# hello
```

Как мы видим, synced_folder заработало. Правда, есть другие типы синхронизации быстрее чем rsync, но это уже совсем другая история




