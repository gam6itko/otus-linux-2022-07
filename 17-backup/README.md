# Backup (borgbackup)

## Задание

Настроить стенд Vagrant с двумя виртуальными машинами: `backup_server` и `client`.
Настроить удаленный бекап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:

- директория для резервных копий /var/backup. Это должна быть отдельная точка монтирования. В данном случае для демонстрации размер не принципиален, достаточно будет и 2GB;
- репозиторий для резервных копий должен быть зашифрован ключом или паролем - на ваше усмотрение;
- имя бекапа должно содержать информацию о времени снятия бекапа;
- глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех. Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов;
- резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации;
- написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на ваше усмотрение;
- настроено логирование процесса бекапа. Для упрощения можно весь вывод перенаправлять в logger с соответствующим тегом. Если настроите не в syslog, то обязательна ротация логов.

Запустите стенд на 30 минут.
Убедитесь что резервные копии снимаются.
Остановите бекап, удалите (или переместите) директорию /etc и восстановите ее из бекапа.
Для сдачи домашнего задания ожидаем настроенные стенд, логи процесса бэкапа и описание процесса восстановления.
Формат сдачи ДЗ - vagrant + ansible


## Полезные ссылки

- https://www.lukmanlab.com/how-to-add-new-disk-in-vagrant/

## Выполнение

Запускаем vagrant с флагом VAGRANT_EXPERIMENTAL чтобы был создан дополнительный диск для бэкапов. В системе он будет обозначен как `/dev/sdc`.
```shell
export VAGRANT_EXPERIMENTAL="disks"
vagrant up
```

### client init

В процессе поднятия клиент в stdout будет отображён ssh ключ, который нужно будет вписать к пользователю borg на backup_server.

### backup_server init

Т.к. нам нужно писать бэкамы с примонтированную лучше для этого использовать папку `/mnt`

После поднятия виртуальных машин нам нужно примонтировать `/dev/sdc`в папку `/mnt/backup`. 
```shell
BACKUP_DEV_SD=/dev/sdc
mkfs.ext4 $BACKUP_DEV_SD
mount $BACKUP_DEV_SD /mnt/backup
```

Добавим созданный на client ssh-pub-key пользователю borg на backup_server руками.

### client backup

Инициализируем репозиторий borg на backup сервере с client сервера. Lt
```shell
borg init --encryption=repokey borg@192.168.57.20:/mnt/backup/
```

Пару раз введём passphrase и бэкам залит на сервер.

Проверяем на backup_server. Файлы бэкапов есть.
```
$ ls -l /mnt/backup/
total 68
-rw------- 1 borg borg    73 Jan 24 21:25 README
-rw------- 1 borg borg   700 Jan 24 21:25 config
drwx------ 3 borg borg  4096 Jan 24 21:25 data
-rw------- 1 borg borg    70 Jan 24 21:25 hints.1
-rw------- 1 borg borg 41258 Jan 24 21:25 index.1
-rw------- 1 borg borg   190 Jan 24 21:25 integrity.1
-rw------- 1 borg borg    16 Jan 24 21:25 nonce
```

Запускаем для проверки создания бэкапа
```shell
borg create --stats --list borg@192.168.57.20:/mnt/backup/::"etc-{now:%Y-%m-%d_%H:%M:%S}" /etc
```

```
------------------------------------------------------------------------------
Repository: ssh://borg@192.168.57.20/mnt/backup
Archive name: etc-2023-01-25_07:01:19
Archive fingerprint: c07d51ee5f7999cc2f35616bb525d38e3deb0cbc3f2be6a679dc5503037016a4
Time (start): Wed, 2023-01-25 07:01:20
Time (end):   Wed, 2023-01-25 07:01:21
Duration: 0.56 seconds
Number of files: 677
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:                2.07 MB            907.78 kB            886.33 kB
All archives:                2.07 MB            907.15 kB            952.92 kB

                       Unique chunks         Total chunks
Chunk index:                     654                  672
------------------------------------------------------------------------------
```

list
```
$ borg list borg@192.168.57.20:/mnt/backup/
etc-2023-01-25_07:01:19              Wed, 2023-01-25 07:01:20 [c07d51ee5f7999cc2f35616bb525d38e3deb0cbc3f2be6a679dc5503037016a4]
```

удалим один файл и попробуем его восстановить из бэкапа
```
$ ls -la /etc/hosts
-rw-r--r-- 1 root root 258 Jan 24 21:18 /etc/hosts

$ sudo rm -rf /etc/hosts

$ ls -la /etc/hosts
ls: cannot access '/etc/hosts': No such file or directory
```

Восстановим из бэкапа
```shell
borg extract borg@192.168.57.20:/mnt/backup::etc-2023-01-25_07:01:19 etc
sudo rsync -av ./etc/ /etc/
```

Файл на месте
```
$ ls -la /etc/hosts
-rw-r--r-- 1 root root 258 Jan 25 10:12 /etc/hosts
```

### systemd

Теперь осталось делать бэкапы по таймеру.

```shell
cp /vagrant/system/* /etc/systemd/system/
systemctl daemon-reload
systemctl enable borg-backup.timer
systemctl start borg-backup.timer
```

Дадим конанде поработать, а потом проверим бэкапы на сервере.
```
$ borg list borg@192.168.57.20:/mnt/backup/
etc-2023-01-25_10:23:41              Wed, 2023-01-25 10:23:42 [5ace284fe0282bb1142684d90a5b38f7d6e5caccf68fbfcb580363dd2fa2c5a3]
etc-2023-01-25_10:23:58              Wed, 2023-01-25 10:23:58 [c7fed98da8016ca346a71331194584fbda07bf983c892b57021eac48e2697cb8]
etc-2023-01-25_10:24:58              Wed, 2023-01-25 10:24:58 [4dbab6afbe00ad3f090fef0ae2c4a48b8a2f9096fc144ae4d3c3db081bf629f1]
etc-2023-01-25_10:26:34              Wed, 2023-01-25 10:26:35 [c727c1bce70fd2ab28b3b4f5b4855116ef3c465d7cd86946c4447052af5d9062]
$ borg list borg@192.168.57.20:/mnt/backup/
etc-2023-01-25_10:23:41              Wed, 2023-01-25 10:23:42 [5ace284fe0282bb1142684d90a5b38f7d6e5caccf68fbfcb580363dd2fa2c5a3]
etc-2023-01-25_10:23:58              Wed, 2023-01-25 10:23:58 [c7fed98da8016ca346a71331194584fbda07bf983c892b57021eac48e2697cb8]
etc-2023-01-25_10:24:58              Wed, 2023-01-25 10:24:58 [4dbab6afbe00ad3f090fef0ae2c4a48b8a2f9096fc144ae4d3c3db081bf629f1]
etc-2023-01-25_10:26:34              Wed, 2023-01-25 10:26:35 [c727c1bce70fd2ab28b3b4f5b4855116ef3c465d7cd86946c4447052af5d9062]
etc-2023-01-25_10:31:36              Wed, 2023-01-25 10:31:37 [90dfa3f27ba70d3e9a7d4b15317023066aa4e3a6dde47a63493df080eb723b87]
```

#### troubleshooting

Если запускать команду создания backup из сервиса, то происходит следующая ошибка:
```
borg.remote.ConnectionClosedWithHint: Connection closed by remote host. Is borg working on the server?
```

На backup_server мы мидим следующую ошибку в файле /var/log/auth.log
```
Jan 25 09:47:46 ubuntu-jammy sshd[3129]: Connection closed by authenticating user borg 192.168.57.10 port 34684 [preauth]
```

Команды для того чтобы копировать
```shell
cp /vagrant/system/* /etc/systemd/system/; systemctl daemon-reload; systemctl start borg-backup.service
journalctl -xeu borg-backup.service
journalctl -u borg-backup.service

systemctl show -pUser borg-backup.service
```

После долни экспериментов промлема решилась тем что была заменена PASSPHRASE на пусту строку. Тогда всё заработало.

