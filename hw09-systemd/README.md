# Инициализация системы. Systemd.

Делал по методичке.

## Задание
Выполнить следующие задания и подготовить развёртывание результата выполнения с использованием Vagrant и Vagrant shell provisioner (или Ansible, на Ваше усмотрение):

1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig).
2. Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi).
3. Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами.
4. * Скачать демо-версию Atlassian Jira и переписать основной скрипт запуска на unit-файл.


## Полезные ссылки

- https://habr.com/ru/company/southbridge/blog/255845/
- https://linuxhint.com/use-logger-command-linux/
- https://www.loggly.com/ultimate-guide/linux-logging-basics/
- https://sed.js.org/


## 1. watchlog

Создаём файл с конфигурацией для сервиса в директории /etc/sysconfig

```shell
cp /vagrant/wl/watchlog.conf /etc/sysconfig/
```

Создаем файл /var/log/watchlog.log
```shell
echo "ALERT! This is otus home work test!" > /var/log/watchlog.log
```

Создаём команду-сервис
```shell
cp /vagrant/wl/watchlog.sh /opt/
chomd a+x /opt/watchlog.sh
```
watchlog.sh при запуске читает их файла, указанного в watchlog.conf если есть искомое слово, то делает запись в syslog (messages).

Создадим unit для systemd и запустим
```shell
cp /vagrant/etc/systemd/system/watchlog.{service,timer}  /etc/systemd/system/
```

Запустим таймер
```shell
systemctl start watchlog.timer
```

```
# systemctl status watchlog.timer
● watchlog.timer - Run watchlog script every 30 second
   Loaded: loaded (/etc/systemd/system/watchlog.timer; disabled; vendor preset: disabled)
   Active: active (elapsed) since Tue 2022-09-06 14:13:27 UTC; 6s ago
  Trigger: n/a

Sep 06 14:13:27 localhost.localdomain systemd[1]: Started Run watchlog script every 30 second.
```

Для проверки, можно в наш целевой лог добавлять строчки следующей командой
```shell
echo "ALERT! Here another one string! " >> /var/log/watchlog.log
```

Проверяем то что сервис отработал
```shell
tail /var/log/messages | grep Master
```

В процессе выполнения этого задания у меня возникла ошибка, что сервис логов не запускался и в `/var/log/messages` не было заветной строки "I found word, Master".
Команда `journalctl -u watchlog.service` помогла обнаружить что сервил всё же запускается каждые 30 секунд.
Команда `watch -n 10 journalctl -n 10 -u watchlog.service` помогла посмотреть что происходит онлайн.
В итоге оказалось, что таймер вызывает команду раз в 30 сек, а моё терпение намного меньше.

Скрипт работает.

## 2. spawn-fcgi

Смотри кто предоставляет пакет `spawn-fcgi`

```
]# yum search spawn-fcgi
Failed to set locale, defaulting to C.UTF-8
Last metadata expiration check: 0:15:51 ago on Tue Sep  6 14:58:12 2022.
No matches found.
```
Оказывается, что у нас нет репозитория, который поставляет этот пакет

Ставим репозиторий и пакет из него
```shell
yum install -y epel-release
yum install -y spawn-fcgi php php-cli mod_fcgid httpd
```

Видим что появился файл `/etc/rc.d/init.d/spawn-fcgi`.

Как я понял, этот сервис работает только с init0 и в нашей системе он не запуститься, т.к. у нас systemd.
Нужно завести его в новой системе.

Раскоментируем строчки в `/etc/sysconfig/spawn-fcgi`

Добавим наш unit конфиг
```shell
cp /vagrant/etc/systemd/system/spawn-fcgi.service  /etc/systemd/system/
systemctl start spawn-fcgi
```

```
# systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2022-09-06 15:33:32 UTC; 7s ago
 Main PID: 2018 (php-cgi)
    Tasks: 33 (limit: 5953)
   Memory: 30.7M
   CGroup: /system.slice/spawn-fcgi.service
           ├─2018 /usr/bin/php-cgi
           ├─2020 /usr/bin/php-cgi
           ├─2021 /usr/bin/php-cgi
           ├─2022 /usr/bin/php-cgi
           ├─2023 /usr/bin/php-cgi

```
Как мы видим у нас получилось завести сервис spawn-fcgi


## 3. apache

После установки httpd в предыдушем задини у нас уже есть файл /usr/lib/systemd/system/httpd@.service.
Нас осталось под него подстроиться

Скопируем файлы настроек сервиса
```shell
/bin/cp -rf /vagrant/httpd/sysconfig/httpd-{first,second} /etc/sysconfig/
/bin/cp -rf /vagrant/httpd/conf/{first,second}.conf /etc/httpd/conf/
```

Копируем и вносим измениния в конфиги сервера apacahe.
```shell
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/first.conf
echo -e 'PidFile /var/run/httpd-first.pid\nServerName first.local' >> /etc/httpd/conf/first.conf
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/second.conf
echo -e 'PidFile /var/run/httpd-second.pid\nServerName second.local' >> /etc/httpd/conf/second.conf
sed -i 's/Listen 80/Listen 8080/' /etc/httpd/conf/second.conf
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.backup
```

Запускаем сервисы и проверяем что они работают
```shell
systemctl start httpd@first.service
systemctl start httpd@second.service

systemctl status httpd@first.service
systemctl status httpd@second.service
```

По строчке `Active: active (running)` мы понимаем, что сервисы запущены и работаеют.
