# SELinux - когда все запрещено

## задание

1. Запустить nginx на нестандартном порту 3-мя разными способами:
  - переключатели setsebool;
  - добавление нестандартного порта в имеющийся тип;
  - формирование и установка модуля SELinux.
  - К сдаче: README с описанием каждого решения (скриншоты и демонстрация приветствуются).

2. Обеспечить работоспособность приложения при включенном selinux.
  - развернуть приложенный стенд https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems;
  - выяснить причину неработоспособности механизма обновления зоны (см. README);
  - предложить решение (или решения) для данной проблемы;
  - выбрать одно из решений для реализации, предварительно обосновав выбор;
  - реализовать выбранное решение и продемонстрировать его работоспособность.

К сдаче:
  README с анализом причины неработоспособности, возможными способами решения и обоснованием выбора одного из них;
  исправленный стенд или демонстрация работоспособной системы скриншотами и описанием.

## выполнение 1

Выполнение делалось по руководством из методички.

Командой `sestatus` проверим что selinux работает
```
$ sestatus
SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
SELinux root directory:         /etc/selinux
Loaded policy name:             targeted
Current mode:                   enforcing
Mode from config file:          enforcing
Policy MLS status:              enabled
Policy deny_unknown status:     allowed
Max kernel policy version:      31
```

Заменим порт nginx на нестандартный 

```shell
# change nginx port
sed -ie 's/:80/:4884/g' /etc/nginx/nginx.conf
sed -i 's/listen\s*80;/listen 4884;/' /etc/nginx/nginx.conf
systemctl restart nginx
```
Запустить nginx не удалось. Смотрим логи
```
# journalctl -u nginx
-- Logs begin at Пт 2023-01-06 09:42:52 UTC, end at Пт 2023-01-06 09:47:58 UTC. --
янв 06 09:47:58 localhost.localdomain systemd[1]: Starting The nginx HTTP and reverse proxy server...
янв 06 09:47:58 localhost.localdomain nginx[22254]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
янв 06 09:47:58 localhost.localdomain nginx[22254]: nginx: [emerg] bind() to 0.0.0.0:4884 failed (13: Permission denied)
янв 06 09:47:58 localhost.localdomain nginx[22254]: nginx: configuration file /etc/nginx/nginx.conf test failed
янв 06 09:47:58 localhost.localdomain systemd[1]: nginx.service: control process exited, code=exited status=1
янв 06 09:47:58 localhost.localdomain systemd[1]: Failed to start The nginx HTTP and reverse proxy server.
янв 06 09:47:58 localhost.localdomain systemd[1]: Unit nginx.service entered failed state.
янв 06 09:47:58 localhost.localdomain systemd[1]: nginx.service failed.
```

Особо интересного тут ничего нет. Попробуем посмотреть в логах аудита командой `audit2why < /var/log/audit/audit.log`.
```
type=AVC msg=audit(1672998478.621:1066): avc:  denied  { name_bind } for  pid=22254 comm="nginx" src=4884 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

        Was caused by:
        The boolean nis_enabled was set incorrectly. 
        Description:
        Allow nis to enabled

        Allow access by executing:
        # setsebool -P nis_enabled 1
```

Видим что subject context `system_u:system_r:httpd_t:s0` не совпадает с object context `system_u:object_r:unreserved_port_t:s0`.


### Способ 1

В выводе audit2why есть подсказка как исправить. 
Попробуем запустить команду `setsebool -P nis_enabled 1`.
Стартуем сервер `systemctl start nginx`.
```
# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Пт 2023-01-06 09:59:18 UTC; 4s ago
  Process: 22413 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
  Process: 22411 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
  Process: 22410 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
 Main PID: 22415 (nginx)
   CGroup: /system.slice/nginx.service
           ├─22415 nginx: master process /usr/sbin/nginx
           └─22417 nginx: worker process
```
Видим что nginx заработал!

#### rollback

```
# setsebool -P nis_enabled 0
# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.
```


### Способ 2

Просто отключаем selinux 😇
```shell
setenforce 0
```
После выполнения этой команды nginx запустится.

#### rollback
```shell
setenforce 1
```


### Способ 3

Теперь разрешим в SELinux работу nginx на порту TCP 4881 c помощью добавления нестандартного порта в имеющийся тип:

```
# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989
```

Добавим порт в тип http_port_t: `semanage port -a -t http_port_t -p tcp 4884`
После выполнения данной команды nginx запуститься без проблем.

#### rollback

Удалим нестандартный порт
```shell
semanage port -d -t http_port_t -p tcp 4884
```


### Способ 4

Разрешим в SELinux работу nginx на порту TCP 4881 c помощью формирования и установки модуля SELinux.
Воспользуемся утилитой audit2allow для того, чтобы на основе логов SELinux сделать модуль, разрешающий работу nginx на нестандартном порту.

```
# grep nginx /var/log/audit/audit.log | audit2allow -M nginx
******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i nginx.pp

# semodule -i nginx.pp
# systemctl restart nginx
```
nginx снова работает!

#### rollback

```
semodule -r nginx
```

## выполнение 1

Скачиваем весь провект с сайта https://github.com/mbfx/otus-linux-adm и копирует из него одну лишь папку `selinux_dns_problems` в этот проект.
Развернём виртуальные машины.

Не удаётся обновить зоны.
```
$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL
> quit
```

Глянем логи SELinux командой `cat /var/log/audit/audit.log | audit2why`.
Нет вывода. Значит нео ошибок.

Посмотрим логи ошибок на сервере `ns01`

```
# cat /var/log/audit/audit.log | audit2why
type=AVC msg=audit(1673713631.389:659): avc:  denied  { create } for  pid=707 comm="isc-worker0000" name="named.ddns.lab.view1.jnl" scontext=system_u:system_r:named_t:s0 tcontext=system_u:object_r:etc_t:s0 tclass=file permissive=0

        Was caused by:
                Missing type enforcement (TE) allow rule.

                You can use audit2allow to generate a loadable module to allow this access.

```

Интересно что это за процесс с PID 707
```
# ps 707
  PID TTY      STAT   TIME COMMAND
  707 ?        Ssl    0:00 /usr/sbin/named -u named -c /etc/named.conf
```

`man named` утверждает что `named` - это "Internet domain name server"

Похоже selinux не даёт этому вервису доступ к папке etc
```
scontext=system_u:system_r:named_t:s0 
tcontext=system_u:object_r:etc_t:s0
```

Глянем на контекст файлов настроек named
```
# ls -laZ /etc/named
drw-rwx---. root named system_u:object_r:etc_t:s0       .
drwxr-xr-x. root root  system_u:object_r:etc_t:s0       ..
drw-rwx---. root named unconfined_u:object_r:etc_t:s0   dynamic
-rw-rw----. root named system_u:object_r:etc_t:s0       named.50.168.192.rev
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab
-rw-rw----. root named system_u:object_r:etc_t:s0       named.dns.lab.view1
-rw-rw----. root named system_u:object_r:etc_t:s0       named.newdns.lab
```

Видим что контекст `system_u:object_r:etc_t:s0` распространяется и на эту папку.

Контекст безопасности неправильный. Проблема в том, что конфигурационные файлы лежат в другом каталоге.
Посмотреть в каком каталоги должны лежать, файлы, чтобы на них
распространялись правильные политики SELinux можно с помощью команды:
`semanage fcontext -l | grep named_`

Видим что в осносном для конфигов используется папка `/var/named/` .

### вариант 1

Нам нужно изменить контекст доступа к папке `/etc/named`.

Для этого постмотрим какие контексты есть у доступных папок `semanage fcontext -l | grep named_` и переходы контекста `sesearch -A -s named_t -c file -p write | grep "allow named_t"`.
Находим общий контекст `named_zone_t`

Приминим команду `chcon -R -t named_zone_t /etc/named` тем самым дадим named писать в папку /etc/named

Теперь если на клиенте запустить команду, то она выполнится без ошибок.
```
nsupdate -k /etc/named.zonetransfer.key <<EOF
server 192.168.50.10
zone ddns.lab
update add www.ddns.lab. 60 A 192.168.50.15
send
quit
EOF
```

### вариант 2

Судя по тому что говорит команда `semanage fcontext -l | grep named_` нам не стоит писать в /etc/names и лучше это делать в папку `/var/names`.
Попробуем изменить расположение конфигов.
Заменим в файле конфига files/ns01/named.conf пути с `/etc/named` на `/var/named` и пересоздалим ВМ.

После пересоздания ВМ на клиенте добавилась зона без ошибок.

Этот вариант самый лучшиий ~~на свете~~!
