# PAM

## Задание

- Запретить всем пользователям, кроме группы admin логин в выходные (суббота и воскресенье), без учета праздников.
- Дать конкретному пользователю права работать с докером и возможность рестартить докер сервис

## Полезные ссылки

- https://linuxize.com/post/how-to-list-groups-in-linux/
- [How to add group](https://linuxize.com/post/how-to-create-groups-in-linux/)
- [System groups](https://wiki.debian.org/SystemGroups)
- https://linux.die.net/man/5/group.conf
- https://linux.die.net/man/8/pam_exec
- https://www.docs4dev.com/docs/en/linux-pam/1.1.2/reference/sag-configuration-file.html
- https://www.freedesktop.org/software/polkit/docs/latest/polkit.8.html

## Выполнение

### Не работать по выходным

```shell
groupadd admin
# добавим пользователя в группу admin
useradd -g admin adam
# пользователь вне группы админ
useradd bob
# добавляем уже существующего пользователя в группу admin
usermod -a -G admin vagrant
echo "1234" | sudo passwd --stdin adam
echo "1234" | sudo passwd --stdin bob
```

Нужно включить модуль pam_time, для этого изменим файл `/etc/pam.d/sshd`. Добавим pam_time после pam_nologin.so

```
#%PAM-1.0
auth       substack     password-auth
auth       include      postlogin
account    required     pam_sepermit.so
account    required     pam_nologin.so
account    required     pam_time.so
account    include      password-auth
password   include      password-auth
# pam_selinux.so close should be the first session rule
session    required     pam_selinux.so close
session    required     pam_loginuid.so
# pam_selinux.so open should only be followed by sessions to be executed in the user context
session    required     pam_selinux.so open env_params
session    required     pam_namespace.so
session    optional     pam_keyinit.so force revoke
session    optional     pam_motd.so
session    include      password-auth
session    include      postlogin
```

Мы будем работать с файлом настроек `/etc/security/time.conf`.
Добавим туда строчку строчку `*;*;!admin;!Al0000-2400`.
Чтобы проверить задание я запрещу заходить по всем дням, но по заданию нужно добавить `*;*;!admin;!Wd0000-2400`;

С помощью команды `ip addr` я выяснил ip машины он `192.168.56.10`. Подключимся к нему по ssh под разными
пользователями.

```shell
$ ssh adam@192.168.56.10
adam@192.168.56.10's password: 
Connection closed by 192.168.56.10 port 22
$ ssh bob@192.168.56.10
bob@192.168.56.10's password: 
Connection closed by 192.168.56.10 port 22
```

Хм. Похоже, у нас проблемы. Наше правило не сработало.
Оказывается модуль pam_time сам по себе работать с группами не может.
Оказалось что нужно делать в несколько шагов. Сначала проверять на группу, если она admin,
то сразу разрешать доступ (sufficient), а если нет, то проверять дальше на время.

Значит в файле `/etc/security/time.conf` должна быть строчка `*;*;*;!Al0000-2400`.

Будем работать с модулем `pam_exec`.

Во время работы возникли трудности с запуском скрипта из папки /vagrant, пробовал разные опции и изменения прав. Не
помогало.
Оказалось что скрипт запускается только из папки `/usr/local/bin`

Добавляем еще одну строчку в файл `/etc/pam.d/sshd`.

```
account    [success=1 default=ignore] pam_exec.so debug log=/tmp/pam_exec.log /usr/local/bin/in_admin_group.sh
account    required     pam_time.so
```

's/account required pam_nologin.so/account    [success=1 default=ignore] pam_exec.so debug log=\/tmp\/pam_exec.log
\/usr/local\/bin\/in_admin_group.sh\naccount required pam_time.so/'

После применения этих правил пробуем войти. Видим что adam может войти а bob нет.

```
$ ssh adam@192.168.56.10
adam@192.168.56.10's password: 
Last failed login: Tue Nov 29 11:20:37 UTC 2022 from 192.168.56.1 on ssh:notty
There was 1 failed login attempt since the last successful login.
Last login: Tue Nov 29 11:19:31 2022 from 192.168.56.1
[adam@localhost ~]$ exit
logout
Connection to 192.168.56.10 closed.
$ ssh bob@192.168.56.10
bob@192.168.56.10's password: 
/usr/local/bin/in_admin_group.sh failed: exit code 1
Connection closed by 192.168.56.10 port 22
```

## Дать конкретному пользователю права работать с докером и возможность рестартить докер сервис

Будем это делать через polkit.
Сначала убедимся что он работает `sudo systemctl status polkit`.
Для того чтобы смотреть его логи будет использовать команду `sudo journalctl -f -u polkit`

Добавим еще одного пользователя carl в группу admin

```shell
useradd carl; echo "1234" | sudo passwd --stdin bob; usermod -a -G admin carl
```

Устанавливаем docker `yum install docker`. Но в almalinux псевдонимом на docker является podman.

Создадим файл `/etc/polkit-1/rules.d/10-podman.rules` c содержимым.
```js
polkit.addRule(function (action, subject) {
    if (
        (action.lookup('unit') === 'podman.service') &&
        action.lookup('verb') === 'restart' &&
        subject.user === 'carl'
    ) {
        return polkit.Result.YES
    }
});
```

Пробуем залогиниться от пользователя carl и выполнить команду `systemctl restart podman`



