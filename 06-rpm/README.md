# Управление пакетами

## UPD 1

Создал provision скрипты для атоматического проделывания всех нижеописанных шагов.
По факту нужно сделать `vagrant up` и долго ждать финальнойстрочки `Zend Engine v4.0.22, Copyright (c) Zend Technologies`,
котора говорит о том, что клиент успешно скачал и установил php из репозитория на `server`.

## Полезные ссылки

- https://www.redhat.com/sysadmin/create-rpm-package
- https://rpm-packaging-guide.github.io/#files
- https://linux.die.net/man/8/rpmbuild
- https://www.vagrantup.com/docs/providers/virtualbox/configuration

## Задание

- создать свой RPM (можно взять свое приложение, либо собрать к примеру апач с определенными опциями);
- создать свой репо и разместить там свой RPM;
- реализовать это все либо в вагранте, либо развернуть у себя через nginx и дать ссылку на репо.
- реализовать дополнительно пакет через docker



## Подготовка окружения.

Создадим  Vagrantfile и поднимем ВМ.

server - сборщик и репозиторий

client - скачивает и устанавливает наш RPM дистрибутив

На мое host-машине стоит процессор AMD Ryzen 5 3500X 6-Core Processor.
Я могу выделить до 6 ядер на VM.
В Vagrantfile для настроек сервера проставим настройку `vb.cpus=4` чтобы сборка шла быстрее.


## Сборка PHP 8.0 с zts

Такая сборка нужна чтобы запустить многопоточный php благодаря расширению <https://www.php.net/manual/en/parallel.setup.php>

Идём на страницу [downloads](https://www.php.net/downloads.php) и скачиваем исходники.

```shell
wget https://www.php.net/distributions/php-8.0.22.tar.gz
tar -xvf php-8.0.22.tar.gz
mv php-8.0.22 php-8.0.22-src
cd php-8.0.22-src
./configure --prefix=/root/php-8.0.22-bin --enable-zts
```

После множественных запусков `configure` мы установили все нужные пакеты.
Так же я добавил из в provisioning shell script для Vagrant.
```shell
yum install -y gcc libxml2-devel sqlite-devel
```

в итоге после очередного запуска configure мы видим нужный текст
```
Generating files
configure: patching main/php_config.h.in
configure: creating ./config.status
creating main/internal_functions.c
creating main/internal_functions_cli.c
config.status: creating main/build-defs.h
config.status: creating scripts/phpize
config.status: creating scripts/man1/phpize.1
config.status: creating scripts/php-config
config.status: creating scripts/man1/php-config.1
config.status: creating sapi/cli/php.1
config.status: creating sapi/phpdbg/phpdbg.1
config.status: creating sapi/cgi/php-cgi.1
config.status: creating ext/phar/phar.1
config.status: creating ext/phar/phar.phar.1
config.status: creating main/php_config.h
config.status: executing default commands

+--------------------------------------------------------------------+
| License:                                                           |
| This software is subject to the PHP License, available in this     |
| distribution in the file LICENSE. By continuing this installation  |
| process, you are bound by the terms of this license agreement.     |
| If you do not agree with the terms of this license, you must abort |
| the installation process at this point.                            |
+--------------------------------------------------------------------+

Thank you for using PHP.
```

Запускаем сборку и идем пить чай.
```shell
make -j$(nproc)
make -j$(nproc) DESTDIR=_build install
```

Всё установилось успешно в папку /root/php-8.0.22-bin. 
Проверяем версию
```
# /root/php-8.0.22-bin/bin/php -v
PHP 8.0.22 (cli) (built: Aug 28 2022 09:59:11) ( ZTS )
Copyright (c) The PHP Group
Zend Engine v4.0.22, Copyright (c) Zend Technologies
```

### сборка RPM

Создаём структура пакета.

```shell
cd /root
yum install -y rpmdevtools rpmlint
rpmdev-setuptree
cp php-8.0.22.tar.gz ./rpmbuild/SOURCES/
```

Создаём spec файл и правим его под наши нужны.
```shell
rpmdev-newspec php
mv php.spec ./rpmbuild/SPECS/
```

Чтобы понять какие макросы что значат поможет команда `rpmbuild --showrc`
Запускаем сборку. 
```shell
/bin/cp /vagrant/php.spec /root/rpmbuild/SPECS/php.spec && rpmbuild -bb /root/rpmbuild/SPECS/php.spec
```

Копируем полученный rpm в общую директорию /vagrant
```shell
cp /root/rpmbuild/RPMS/x86_64/php-8.0.22-1.el8.x86_64.rpm /vagrant/
```

#### client

Подключаемся в ВМ client и пытаемся установить собранный пакет
```shell
rpm -i /vagrant/php-8.0.22-1.el8.x86_64.rpm
```

Проверяем
```
# /usr/local/bin/php -v
PHP 8.0.22 (cli) (built: Aug 28 2022 21:22:47) ( ZTS )
Copyright (c) The PHP Group
Zend Engine v4.0.22, Copyright (c) Zend Technologies 
```
Как видим пакет удалось установить.

Выяснил проблему, что просто команда `php -v` не работает. Скорее всего потому что мы не сделали ссылку в папку /bin.
Лечится такой командой `ln -s /usr/local/bin/php /bin/php`


### создание репозитория

#### Сервер

Устанавливаем nginx
```shell
yum install -y nginx
systemctl enable nginx
systemctl start nginx
```

Т.к. машины работаетю по dhcp, выясняем ip сервера.
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
       valid_lft 85487sec preferred_lft 85487sec
    inet6 fe80::a00:27ff:fe7a:1db8/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
3: enp0s8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:51:ce:76 brd ff:ff:ff:ff:ff:ff
    inet 192.168.56.6/24 brd 192.168.56.255 scope global dynamic noprefixroute enp0s8
       valid_lft 587sec preferred_lft 587sec
    inet6 fe80::a00:27ff:fe51:ce76/64 scope link 
       valid_lft forever preferred_lft forever
```

Из браузера заходим на адресс http://192.168.56.6/ и видем заставку nginx. 
Значит сервер работает.


```shell
yum install -y createrepo
mkdir -p /usr/share/nginx/html/repo/x86_64
cp /root/rpmbuild/RPMS/x86_64/php-8.0.22-1.el8.x86_64.rpm /usr/share/nginx/html/repo/x86_64
createrepo /usr/share/nginx/html/repo/x86_64
```

#### Клиент

Для начала пересоздадим клиентскую машину.
На host machine запустим
```shell
vagrant destroy -f client && vagrant up client
vagrant ssh client
```

Создадим файл нашего
```shell
/bin/cp /vagrant/yum.repos.d/my.repo /etc/yum.repos.d/
```

Проверим 
```
# yum repolist enabled
Failed to set locale, defaulting to C.UTF-8
repo id                                        repo name
appstream                                      AlmaLinux 8 - AppStream
baseos                                         AlmaLinux 8 - BaseOS
extras                                         AlmaLinux 8 - Extras
myrepo                                         My repo
```

Наш репозиторий виден.
Проверим пакеты, которые он поставляет
```
# yum list --repo myrepo | grep myrepo
php.x86_64                          8.0.22-1.el8                            myrepo 
```

Попробуем установить пакет из нашего репозитория
```shell
yum install -y --repo myrepo php
```
Команда звершилась без ошибок.

Проверяем.
```
# /usr/local/bin/php -v
PHP 8.0.22 (cli) (built: Aug 28 2022 21:22:47) ( ZTS )
Copyright (c) The PHP Group
Zend Engine v4.0.22, Copyright (c) Zend Technologies
```

Как мы видим, мы успешно установили php из пакета, который раздаётся с другой машины.
