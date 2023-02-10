# LDAP, FreeIpa

## Задание

- Установить FreeIPA;
- Написать Ansible playbook для конфигурации клиента;
- *. Настроить аутентификацию по SSH-ключам;
- **. Firewall должен быть включен на сервере и на клиенте.


## Полезные материалы 

- https://floblanc.wordpress.com/2017/09/11/troubleshooting-freeipa-pki-tomcatd-fails-to-start/
- https://freeipa.readthedocs.io/en/latest/workshop/10-ssh-key-management.html

## Выполнение

Изначально выполнялось на centos/7. НО!
После provision должен настроиться ipa server и client.

### Troubleshooting

Сразу же с порога ipa-server не захотел устанавливается.

```
ipapython.admintool: ERROR    CA did not start in 300.0s
ipapython.admintool: ERROR    The ipa-server-install command failed. See /var/log/ipaserver-install.log for more information
```

В логах `/var/log/ipaserver-install.log` наблюдаем следующую ошибку.
```
2023-02-10T15:57:22Z DEBUG Waiting for CA to start...
2023-02-10T15:57:23Z DEBUG request POST http://server.ldap.local:8080/ca/admin/ca/getStatus
2023-02-10T15:57:23Z DEBUG request body ''
2023-02-10T15:57:23Z DEBUG response status 500
```

Порт 8080 у нас прослушивает некая java (скорее всего это tomcat). Нужно посмотреть его логи `cat /var/log/pki/pki-tomcat/ca/debug`.
Видим следующее
```
[10/Feb/2023:15:52:27][localhost-startStop-1]: SSL handshake happened
Could not connect to LDAP server host server.ldap.local port 636 Error netscape.ldap.LDAPException: Authentication failed (48)
```

После долгих и безрезультатных попыток я решил поменять дистрибутив на almalinux/8 и всё заработало. 🤔

### Проверка работы

На server добавим еще одного пользователя. Пароль: 12345.

Нужно сначала залогиниться в Kerberos.
```
# kinit admin
Password for admin@OTUS.LAN:

# klist
Ticket cache: KEYRING:persistent:0:0
Default principal: admin@OTUS.LAN

Valid starting       Expires              Service principal
10/25/2019 20:43:57  10/26/2019 20:43:52  krbtgt/OTUS.LAN@OTUS.LAN

# ipa user-add --first="John"  --last="Doe" --cn="John Doe" johndoe
--------------------
Added user "johndoe"
--------------------
  User login: johndoe
  First name: John
  Last name: Doe
  Full name: John Doe
  Display name: John Doe
  Initials: JD
  Home directory: /home/johndoe
  GECOS: John Doe
  Login shell: /bin/sh
  Principal name: johndoe@LDAP.LOCAL
  Principal alias: johndoe@LDAP.LOCAL
  Email address: johndoe@ldap.local
  UID: 783200004
  GID: 783200004
  Password: False
  Member of groups: ipausers
  Kerberos keys available: False
  
# ipa user-mod johndoe --password
Password: 
Enter Password again to verify: 
-----------------------
Modified user "johndoe"
-----------------------
  User login: johndoe
  First name: John
  Last name: Doe
  Home directory: /home/johndoe
  Login shell: /bin/sh
  Principal name: johndoe@LDAP.LOCAL
  Principal alias: johndoe@LDAP.LOCAL
  Email address: johndoe@ldap.local
  UID: 783200004
  GID: 783200004
  Account disabled: False
  Password: True
  Member of groups: ipausers
  Kerberos keys available: True
```

Проверим что пользователь создался
```
[root@server ~]# whoami
root
[root@server ~]# su - johndoe
Creating home directory for johndoe.
[johndoe@server ~]$ whoami
johndoe
[johndoe@server ~]$ exit
logout
```

> Можно заметить что если выполнить команду `cat /etc/passwd | grep john` то ничего не отобразится. 
    Значит пользователи хранятся в другом месте.


### Client

Зайдём на клиент и проверим есть ли там пользователь johndoe.
```
[root@client ~]# whoami
root
[root@client ~]# su - johndoe
Creating home directory for johndoe.
[johndoe@client ~]$ whoami
johndoe
[johndoe@client ~]$ exit
logout
```

### Client ssh login with password

Теперь попробуем зайти на сервер по ssh. Предварительно нужно с помощью команды `vagrant ssh-config` узнать ssh port машины `client` (у меня он 2200). 

С host-machine выаолняем следующее.
```
gam6itko@gam6itko-home-pc:~/25-ldap$ ssh -p 2200 johndoe@127.0.0.1

The authenticity of host '[127.0.0.1]:2200 ([127.0.0.1]:2200)' can't be established.
ED25519 key fingerprint is SHA256:ztgOsAsmpxqFfsfdfSwOwiTTZJW1+ZN+Gx5uDIESUq4.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '[127.0.0.1]:2200' (ED25519) to the list of known hosts.
(johndoe@127.0.0.1) Password: 
(johndoe@127.0.0.1) Password expired. Change your password now.
Current Password: 
(johndoe@127.0.0.1) New password: 
(johndoe@127.0.0.1) Retype new password: 
Password change failed. Server message: Password is too short

Password not changed.

johndoe@127.0.0.1's password: 
```

При попытке установить новый пароль (qwert) мы получаем ошибку `Password not changed`.
Оказывается новый пароль должен быть не менее 8 символов длинной. Поэтому мы задаём новый пароль: "1234567890"

После удачной установки нового пароля мы должны увидеть такую картину
```
Last failed login: Sat Feb 11 13:09:43 UTC 2023 from 10.0.2.2 on ssh:notty
There were 7 failed login attempts since the last successful login.
Last login: Sat Feb 11 12:21:59 2023
[johndoe@server ~]$ whoam i
-sh: whoam: command not found
[johndoe@server ~]$ whoami
johndoe
```

### Client ssh login with ssh


На server-machine под пользователем johndoe я сгенерировал ssh ключ `ssh-keygen`.

```
[root@server ~]# kinit johndoe
Password for johndoe@LDAP.LOCAL: 
Password expired.  You must change it now.
Enter new password: 
Enter it again: 

[root@server ~]# ipa user-mod johndoe --sshpubkey="$(cat /home/johndoe/.ssh/id_rsa.pub)"
-----------------------
Modified user "johndoe"
-----------------------
  User login: johndoe
  First name: John
  Last name: Doe
  Home directory: /home/johndoe
  Login shell: /bin/sh
  Principal name: johndoe@LDAP.LOCAL
  Principal alias: johndoe@LDAP.LOCAL
  Email address: johndoe@ldap.local
  UID: 344600003
  GID: 344600003
  SSH public key: ssh-rsa
                  AAAAB3NzaC1yc2EAAAADAQABAAABgQCqX1vcpAVf6RkNlg5zneDKK+uzcvlnY5TIrVW0XIV7UblrlDSV/J4PeDuUYitPLXxynzu7r41Ye1CX1taDK+0veqgYKCX0BfQwY0O8fTTT/H/b0uw4wye4r2lnjKFoL8vCqmM+tlmgS3929OiR83nyjAaYnUegsjQieoN9Ax/oAi5p/qSpo4zhJjh0n+pSI9W1Gez5JTOlqMV6V8665UqsHNCuJsFD4rFj0qpFkP/m6wesBDi7WHCbFIrY2Y4vN82CrRAMgIg4SIH+AaLaTi7bImtrl2s5XEtnAuN3oL5k/bCf3cfhwfYrrZKzrzceXzw5ikYYJCIsdVLaosu57G6NuSilp4r5Ooyrl8005SAZuPTUH9X2iIOp02PUpzJufPJTIjgwXsDrjgozK4F78Ee+HNmksKolYW+4JOceObRyBcvXj9x+vy9HdRL7tdoTcXNxTpWprXB/jwpsze4t7AFQE780Bazh7dKK5UJnKzw/BdgSsR7ZFoPINVFP/nAltN8=
                  johndoe@server.ldap.local
  SSH public key fingerprint: SHA256:qqDs0netis5EnY8jmOzPVo2tCu3uU9h9RVzBUEsYgco johndoe@server.ldap.local
                              (ssh-rsa)
  Account disabled: False
  Password: True
  Member of groups: ipausers
  Kerberos keys available: True
```

Из файла копируем ключ /home/johndoe/.ssh/id_rsa и сохраняем на host-machine в файл johndoe.pri с правами 0600.

Пробуем зайти по ssh на client. ( ssh-порт 2200)
```
gam6itko@gam6itko-home-pc:~/otus-linux-2022-07/25-ldap$ ssh -p 2200 -i ./johndoe.pri johndoe@127.0.0.1
The authenticity of host '[127.0.0.1]:2200 ([127.0.0.1]:2200)' can't be established.
ED25519 key fingerprint is SHA256:AfTGTDsoW/xT0L7D8ETZzvGWtvsbJYLgzeTw/bcUSU0.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '[127.0.0.1]:2200' (ED25519) to the list of known hosts.
[johndoe@client ~]$ hostname
client.ldap.local
```

Как видим зайти по ssh-key на client удалось.
