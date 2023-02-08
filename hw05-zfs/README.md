# ZFS

## полезные материалы

https://www.youtube.com/channel/UCgY050JAKtaew3IEgGW1qSQ

https://linuxhint.com/enable-zfs-compression/

## задание

Цель:
Отрабатываем навыки работы с созданием томов export/import и установкой параметров.

- определить алгоритм с наилучшим сжатием;
- определить настройки pool’a;
- найти сообщение от преподавателей.

Результат:
список команд, которыми получен результат с их выводами.

### Описание/Пошаговая инструкция выполнения домашнего задания:

#### 1. Определить алгоритм с наилучшим сжатием.
Зачем: отрабатываем навыки работы с созданием томов и установкой параметров. Находим наилучшее сжатие.

Шаги:
- определить какие алгоритмы сжатия поддерживает zfs (gzip gzip-N, zle lzjb, lz4);
- создать 4 файловых системы на каждой применить свой алгоритм сжатия;

Для сжатия использовать либо текстовый файл либо группу файлов:
- скачать файл “Война и мир” и расположить на файловой системе wget -O War_and_Peace.txt http://www.gutenberg.org/ebooks/2600.txt.utf-8, либо скачать файл ядра распаковать и расположить на файловой системе.

Результат:
- список команд которыми получен результат с их выводами;
- вывод команды из которой видно какой из алгоритмов лучше.

#### 2. Определить настройки pool’a.

Зачем: для переноса дисков между системами используется функция export/import. Отрабатываем навыки работы с файловой системой ZFS.

Шаги:
- загрузить архив с файлами локально. https://drive.google.com/open?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg
- Распаковать.
- с помощью команды zfs import собрать pool ZFS;
- командами zfs определить настройки:
  - размер хранилища;
  - тип pool;
  - значение recordsize;
  - какое сжатие используется;
  - какая контрольная сумма используется.

Результат:
- список команд которыми восстановили pool . Желательно с Output команд;
- файл с описанием настроек settings.

#### 3. Найти сообщение от преподавателей.
Зачем: для бэкапа используются технологии snapshot. Snapshot можно передавать между хостами и восстанавливать с помощью send/receive. Отрабатываем навыки восстановления snapshot и переноса файла.

Шаги:
- скопировать файл из удаленной директории. https://drive.google.com/file/d/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG/view?usp=sharing
Файл был получен командой `zfs send otus/storage@task2 > otus_task2.file`
- восстановить файл локально. `zfs receive`
- найти зашифрованное сообщение в файле secret_message

Результат:
- список шагов которыми восстанавливали;
- зашифрованное сообщение.



## Выполнение ДЗ

### подготовка

Копируем из репозитория <https://github.com/nixuser/virtlab/tree/main/zfs> файлы `setup_zfs.sh` и `Vagrantfile`.
Вносим изменения из лекции.

Запускаем vm
```shell
export VAGRANT_EXPERIMENTAL="disks"
vagrant up
vagrant ssh server
```

### 1. Определить алгоритм с наилучшим сжатием.

Создаём zpool
```shell
zpool create zpool1 mirror /dev/sdb /dev/sdc
```

```
# zpool list
NAME     SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
zpool1   960M   100K   960M        -         -     0%     0%  1.00x    ONLINE  -
```

Создадим несколько dataset и для каждого назначим свой алгоритм сжатия (gzip gzip-9, zle lzjb, lz4, zstd)
```shell
zfs create zpool1/ds_gzip1
zfs set compression=gzip zpool1/ds_gzip1
zfs create zpool1/ds_gzip9
zfs set compression=gzip zpool1/ds_gzip9
zfs create zpool1/ds_zle
zfs set compression=zle zpool1/ds_zle
zfs create zpool1/ds_lzjb
zfs set compression=lzjb zpool1/ds_lzjb
zfs create zpool1/ds_lz4
zfs set compression=lz4 zpool1/ds_lz4
zfs create zpool1/ds_zstd
zfs set compression=zstd zpool1/ds_zstd
```

Проверим какие компрессии включены.
```
# zfs get compression
NAME             PROPERTY     VALUE           SOURCE
zpool1           compression  off             default
zpool1/ds_gzip1  compression  gzip            local
zpool1/ds_gzip9  compression  gzip            local
zpool1/ds_lzjb   compression  lzjb            local
zpool1/ds_zle    compression  zle             local
zpool1/ds_zstd   compression  zstd            local
```

#### linux kernel

Скачиваем ядро линукс на один из датасетов и копируем его на другие. 
Чтобы это сделать пришлось установить `wget`.
```shell
wget -O /tmp/kernel.tar.xz https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.19.3.tar.xz
cp /tmp/kernel.tar.xz /zpool1/ds_gzip1/
cp /tmp/kernel.tar.xz /zpool1/ds_gzip9/
cp /tmp/kernel.tar.xz /zpool1/ds_zle/
cp /tmp/kernel.tar.xz /zpool1/ds_lzjb/
cp /tmp/kernel.tar.xz /zpool1/ds_lz4/
cp /tmp/kernel.tar.xz /zpool1/ds_zstd/
```
Копирование происходит не влёт.


С помощью комманды `zfs get compressratio` выведем данные об уровне сжатия.
```
# zfs get compressratio
NAME             PROPERTY       VALUE  SOURCE
zpool1           compressratio  1.00x  -
zpool1/ds_gzip1  compressratio  1.00x  -
zpool1/ds_gzip9  compressratio  1.00x  -
zpool1/ds_lz4    compressratio  1.00x  -
zpool1/ds_lzjb   compressratio  1.00x  -
zpool1/ds_zle    compressratio  1.00x  -
zpool1/ds_zstd   compressratio  1.00x  -
```
Видим, что на бинарном файле никакая компрессия не эффективна.


#### текстовой файл "Война и мир"

Удалим файлы ядра ликсы для чистоты эксперимента
```shell
rm -f /zpool1/ds_gzip1/kernel.tar.xz
rm -f /zpool1/ds_gzip9/kernel.tar.xz
rm -f /zpool1/ds_lz4/kernel.tar.xz
rm -f /zpool1/ds_lzjb/kernel.tar.xz
rm -f /zpool1/ds_zle/kernel.tar.xz
rm -f /zpool1/ds_zstd/kernel.tar.xz
```


```shell
wget -O /tmp/war_peace.txt https://www.gutenberg.org/cache/epub/2600/pg2600.txt
cp /tmp/war_peace.txt /zpool1/ds_gzip1/
cp /tmp/war_peace.txt /zpool1/ds_gzip9/
cp /tmp/war_peace.txt /zpool1/ds_zle/
cp /tmp/war_peace.txt /zpool1/ds_lzjb/
cp /tmp/war_peace.txt /zpool1/ds_lz4/
cp /tmp/war_peace.txt /zpool1/ds_zstd/
```

Проверяем степень сжатия
```
# zfs get compressratio
NAME             PROPERTY       VALUE  SOURCE
zpool1           compressratio  1.72x  -
zpool1/ds_gzip1  compressratio  2.67x  -
zpool1/ds_gzip9  compressratio  2.67x  -
zpool1/ds_lz4    compressratio  1.63x  -
zpool1/ds_lzjb   compressratio  1.36x  -
zpool1/ds_zle    compressratio  1.01x  -
zpool1/ds_zstd   compressratio  2.59x  -
```

Мы можем сделать вывод, что на текстовых данных от сжатия есть эффект и саммым эффективным алгоритмом является `gzip` (на важно какой уровень).
На втором месте `zstd`.
Алгоритм `zle` практически не эффективен.



### 2. Определить настройки pool’a.

Удаляем zpool из предыдущего задания командой `zpool destroy zpool1`

```shell
wget -O /tmp/zfs_task.tar.gz https://drive.google.com/u/0/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg
cd /tmp
tar -xf zfs_task.tar.gz
```

Сканируем скачаную папку на наличие zpool
```
# zpool import -d /tmp/zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
status: Some supported features are not enabled on the pool.
        (Note that they may be intentionally disabled if the
        'compatibility' property is set.)
 action: The pool can be imported using its name or numeric identifier, though
        some features will not be available without an explicit 'zpool upgrade'.
 config:

        otus                        ONLINE
          mirror-0                  ONLINE
            /tmp/zpoolexport/filea  ONLINE
            /tmp/zpoolexport/fileb  ONLINE
```

Видим что у нас есть одни zpool с именем otus. Импортируем его
```shell
zpool import -d /tmp/zpoolexport/ otus
```

```
# zpool list
NAME     SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus     480M  2.09M   478M        -         -     0%     0%  1.00x    ONLINE  -
zpool2   960M   102K   960M        -         -     0%     0%  1.00x    ONLINE  -
 


# zpool status otus
  pool: otus
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
        The pool can still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
        the pool may no longer be accessible by software that does not support
        the features. See zpool-features(7) for details.
config:

        NAME                        STATE     READ WRITE CKSUM
        otus                        ONLINE       0     0     0
          mirror-0                  ONLINE       0     0     0
            /tmp/zpoolexport/filea  ONLINE       0     0     0
            /tmp/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors



# zfs get recordsize otus
NAME  PROPERTY    VALUE    SOURCE
otus  recordsize  128K     local



# zfs get compression otus
NAME  PROPERTY     VALUE           SOURCE
otus  compression  zle             local



# zfs get checksum otus
NAME  PROPERTY  VALUE      SOURCE
otus  checksum  sha256     local
```

размер хранилища: 480M
тип pool: mirror
значение recordsize: 128K
какое сжатие используется: zle
какая контрольная сумма используется: sha256



#### 3. Найти сообщение от преподавателей.

```shell
wget -O /tmp/otus_task2.file https://drive.google.com/u/0/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG
```

Создадим новый zpool командой `zpool create zpool3 mirror /dev/sdb /dev/sdd`

Восстанавливаем из снапшота
```script
zfs receive zpool3/message < /tmp/otus_task2.file
```

Ищём файл `secret_message` командой find
```
# find /zpool3/message/ -name 'secret_message'
/zpool3/message/task1/file_mess/secret_message
```
Так же можно искать глазами с помощью команды `tree /zpool3/message/`

```
# cat /zpool3/message/task1/file_mess/secret_message 
https://github.com/sindresorhus/awesome
```

Секретное сообщение: https://github.com/sindresorhus/awesome
