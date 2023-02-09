# Фильтрация трафика - firewalld, iptables, nfttables

## Задание

Сценарии iptables

- реализовать knocking port
  - centralRouter может попасть на ssh inetrRouter через knock скрипт
- добавить inetRouter2, который виден(маршрутизируется (host-only тип сети для виртуалки)) с хоста или форвардится порт через локалхост.
- запустить nginx на centralServer.
- пробросить 80й порт на inetRouter2 8080.
- дефолт в инет оставить через inetRouter.

Формат сдачи ДЗ - vagrant + ansible
* реализовать проход на 80й порт без маскарадинга

## Полезные материалы

- https://www.calculator.net/random-number-generator.html
- https://ru.wikibooks.org/wiki/Iptables
- https://developer.hashicorp.com/vagrant/docs/providers/virtualbox/networking
- https://www.digitalocean.com/community/tutorials/how-to-forward-ports-through-a-linux-gateway-with-iptables


## Выполнение

### Port knocking

#### Прежде чем начать

Нужно обеспечить доступ по ssh centralRouter -> inetRouter.
Для этого генерируем ключ на centralRouter и добавить его на inetRouter.

Проверяем соединение
```shell
ssh vagrant@192.168.61.10
```

#### Что удалось выяснить 

Чтобы понять как это делается пришлось немного почитать и поразбирать примеры в сети. 

Чтобы понять как сделать Port Knocking нужно понимать следующие аспекты iptables

- Окромя втроенных цепочек (INPUT, OUTPUT, etc..) можно создать свою цепочку (`iptables -N my_chain`)
- Флаг '-j' полное имя '--jump' обозначет переход к какому-то действию.
    Можно осуществить переход к терминальному действи (ACCEPT, DROP), а можно переход в цепочку (my_chain). 
    Таким образом можно "скакать" по цепочкам вглюбь сколько нужно.
- Критерий `-m recent` может сохранять информацию о входящем соединении в список. 
  Пример: `iptables -A INPUT -m recent --name SSH2 --set -j DROP`

Из вышеперечисленного алгоритм может быть следующий:
- При подключении к PORT1 помещаем IP в список IP_LIST0.
- При подключении к PORT2 проверяем есть ли IP в списке IP_LIST0, если да то помещаем в список IP_LIST1.
  Эту итерацию можно проворачивать сколько угодно раз
- ...
- При подключении к PORT_9999 проверяем есть ли IP в списке IP_LIST9999, если да то разрешаем соединени.


#### Пишем правило для iptables

Случайно сгенерирует на [сайте](https://www.calculator.net/random-number-generator.html) 3 порта.
- PORT1: 7777
- PORT2: 8888
- PORT3: 9999

Тогда последовательность команду на машине **inetRouter** будет такая.
```shell
sudo /vagrant/files/port_knock.sh
```

Чтобы сохранить настройки нужно выполнить. 
Если выйти их машины inetRouter, то зайти в неё с помощью команды `vagrant ssh` будет невозможно.
```shell
iptables-save > /etc/sysconfig/iptables-config
```

#### Пробуем достучаться с centralRouter

C centralRouter ping проходит.

Теперь подключение по ssh не должно работать как раньше.
```shell
ssh vagrant@192.168.61.10
```

```shell
# порт 1111 добавлен чтобы скинуть стуки
/vagrant/knock.sh 192.168.61.10 1111 7777 8888 9999
ssh vagrant@192.168.61.10
```

С первого раза подключиться не удалось и я решил добавить логов в iptables. 
Далее мониторим поведение через команду `tail -f /var/log/messages`.

В итоге с помощью логов удалось устранить проблему.


### inetRouter2:8080 <=> centralRouter:80

#### Немного о vagrant network

У сетей вагранта есть особенность.

```
# hostonly  - можно подключаться с host machine
node.vm.network "private_network",  ip: "192.168.61.30"
# intnet  - нельзя подключаться с host machine
node.vm.network "private_network", ip: "192.168.61.30", virtualbox__intnet: true
```

У inetRouter2 создадим 2 разные сети
```
# подсеть, которая присваивается dhcp
node.vm.network "private_network", ip: "192.168.56.120"
# внутренняя сеть с inetRouter и centralRouter
node.vm.network "private_network", ip: "192.168.61.30", virtualbox__intnet: true
```

#### iptables rules

Нам необходимо сделать чтобы inetRouter2 при обращении на 8080 порт перенаправлял трафик на centralRouter.

Это можно сделать с помощью iptables и таблицы nat.

Для начала отобразим сетевые интерфейсы.
```
# ip -br a
lo               UNKNOWN        127.0.0.1/8 ::1/128 
enp0s3           UP             10.0.2.15/24 fe80::a00:27ff:fe7a:1db8/64 
enp0s8           UP             192.168.56.120/24 fe80::a00:27ff:fe16:d89c/64 
enp0s9           UP             192.168.61.30/24 fe80::a00:27ff:fed1:a7a6/64 
```

```
sudo /vagrant/files/fwd_nginx.sh
```

Проверяем проброс портов `curl --connect-timeout 1 --retry 0 192.168.56.120`.

Видим что ответ пришёл
```
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
    <head>
        <title>Test Page for the Nginx HTTP Server on AlmaLinux</title>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <style type="text/css">
...
...
```

Вохраним настройки в файле 
```
iptables-save > /etc/sysconfig/iptables-config
```

## Ansible

Для машины inerRouter будет выдавать ошибку `Failed to confirm state restored from /vagrant/files/port_knock.rules after 30s`.
Это нормально. Т.к. в этой команде добавили правило `-P INPUT DROP`. 
Port knocking всё равно уже работает.
