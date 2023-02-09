# network

## задание

### Дано
Vagrantfile с начальным  построением сети
inetRouter
centralRouter
centralServer

тестировалось на virtualbox

### Планируемая архитектура
построить следующую архитектуру

Сеть office1
- 192.168.2.0/26    - dev
- 192.168.2.64/26   - test servers
- 192.168.2.128/26  - managers
- 192.168.2.192/26  - office hardware

Сеть office2
- 192.168.1.0/25    - dev
- 192.168.1.128/26  - test servers
- 192.168.1.192/26  - office hardware


Сеть central
- 192.168.0.0/28   - directors
- 192.168.0.32/28  - office hardware
- 192.168.0.64/26  - wifi

```
Office1 ---\
      -----> Central --IRouter --> internet
Office2----/
```
Итого должны получится следующие сервера
- inetRouter
- centralRouter
- office1Router
- office2Router
- centralServer
- office1Server
- office2Server

### Теоретическая часть
- Найти свободные подсети
- Посчитать сколько узлов в каждой подсети, включая свободные
- Указать broadcast адрес для каждой подсети
- проверить нет ли ошибок при разбиении

### Практическая часть
- Соединить офисы в сеть согласно схеме и настроить роутинг
- Все сервера и роутеры должны ходить в инет через inetRouter
- Все сервера должны видеть друг друга
- у всех новых серверов отключить дефолт на нат (eth0), который вагрант поднимает для связи
- при нехватке сетевых интервейсов добавить по несколько адресов на интерфейс


## Полезные ссылки

- https://www.calculator.net/ip-subnet-calculator.html
- https://www.youtube.com/@merionacademy
- https://www.youtube.com/playlist?list=PL6gG7zVB_EJzlGEXldo2-PQUtDI8YYUW9
- https://losst.pro/nastrojka-seti-v-linux
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/deployment_guide/ch-network_interfaces#s1-networkscripts-files
- https://github.com/sid1980/otus-linux/tree/master/hw18

## Выполнение

Т.к. я плохо разбираюсь в сетях и тем более не понимаю что от меня хотят в задании, то будем проходито этот путь вместе.

### Теоретическа часть

Для начала проверим на калькуряторе сетей корректность выделенных диапазонов.

| name            | subnet           | hosts allowed | from          | to            | broadcast     |
|-----------------|------------------|---------------|---------------|---------------|---------------|
| central         |                  |               |               |               |               |
| directors       | 192.168.0.0/28   | 14            | 192.168.0.1   | 192.168.0.14  | 192.168.0.15  |
| office hardware | 192.168.0.32/28  | 14            | 192.168.0.33  | 192.168.0.46  | 192.168.0.47  |
| wifi            | 192.168.0.64/26  | 62            | 192.168.0.65  | 192.168.0.126 | 192.168.0.127 |
| office2         |                  |               |               |               |               |
| dev             | 192.168.1.0/25   | 126           | 192.168.1.1   | 192.168.1.126 | 192.168.1.127 |
| test servers    | 192.168.1.128/26 | 62            | 192.168.1.129 | 192.168.1.190 | 192.168.1.191 |
| office hardware | 192.168.1.192/26 | 62            | 192.168.1.193 | 192.168.1.254 | 192.168.1.255 |
| office1         |                  |               |               |               |               |
| dev             | 192.168.2.0/26   | 62            | 192.168.2.1   | 192.168.2.62  | 192.168.2.63  |
| tests servers   | 192.168.2.64/26  | 62            | 192.168.2.65  | 192.168.2.126 | 192.168.2.127 |
| managers        | 192.168.2.128/26 | 62            | 192.168.2.129 | 192.168.2.190 | 192.168.2.191 |
| office hardware | 192.168.2.192/26 | 62            | 192.168.2.193 | 192.168.2.254 | 192.168.2.255 |


Свободные диапазоны.

| name             | hosts allowed |
|------------------|---------------|
| central          |               |
| 192.168.0.16/28  | 14            |
| 192.168.0.48/28  | 14            |
| 192.168.0.128/25 | 126           |

Судя по всему выделенный нам диапазон ip `192.168.0.0/16` (192.168.0.0 - 192.168.255.255).
Так что у нас минимум есть свободный диапазон 192.168.3.0-192.168.254.255

#### Подсети роутеров

Чтобы office1Router и office2ROuter ходили в интернет через centralRouter их нужно объединить в отдельные подсети.

- 192.168.255.0/30 
  - inetRouter    192.168.255.1  
  - centralRouter 192.168.255.2  
- 192.168.255.4/30
  - centralRouter 192.168.255.5
  - office1Router 192.168.255.6
- 192.168.255.8/30
    - centralRouter 192.168.255.9
    - office2Router 192.168.255.10

### Практическа часть

Схему сети можно посмотреть в файле network.drawio.
Рисование схемы помогло мне разобраться как всё должно быть устроено.
В итоге в Vagrantfile были внесены измениния с новыми машинами и настройкой сетевых интерфейсов.

#### Все сервера и роутеры должны ходить в инет через inetRouter


##### Перезагрузка служб

При изучении Vagrantfile я обратил снимание на следующие строчки

```
when "centralServer"
  box.vm.provision "shell", run: "always", inline: <<-SHELL
    echo "DEFROUTE=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
    echo "GATEWAY=192.168.0.1" >> /etc/sysconfig/network-scripts/ifcfg-eth1
    systemctl restart network
    SHELL
```

Здесь используется настройка интерфейсов через файлы. Об этом можно почитать [здесь](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/deployment_guide/s1-networkscripts-interfaces).
По идее если мы наберём команду `ip -c r` то должны увидеть строчку `default via 192.168.255.1`.

```
$ ip -c r
default via 10.0.2.2 dev eth0 proto dhcp metric 102 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 102 
192.168.0.0/28 dev eth1 proto kernel scope link src 192.168.0.2 metric 100 
```

Хм. Ожидание не оправдалось. Попробуем перезапустить службу `systemctl restart network`
```
$ sudo systemctl restart network
$ ip r
default via 192.168.0.1 dev eth1 proto static metric 101 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
192.168.0.0/28 dev eth1 proto kernel scope link src 192.168.0.2 metric 101 
```

Как мы видим по какой-то причине по время создания машин. Служба не перезапускается. 
Скорее всего это связано с тем что vagrant не даёт изменить настройки сети пока полностью не поднимет весь парк машин.

Чтобы исправить этот недочёт я написал скрипт `restart_all_networks.sh`, который перезагрузит службы во всех машинах.

Зайдём в машину centralRouter и проверим роуты. Видим что скрипт помог.
```
$ ip r
default via 192.168.255.1 dev eth1 proto static metric 101 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
192.168.0.0/28 dev eth2 proto kernel scope link src 192.168.0.1 metric 102 
192.168.0.32/28 dev eth3 proto kernel scope link src 192.168.0.33 metric 103 
192.168.0.64/26 dev eth4 proto kernel scope link src 192.168.0.65 metric 104 
192.168.255.0/30 dev eth1 proto kernel scope link src 192.168.255.2 metric 101 
```

##### Доступ к интернету через inetRouter

Далее мы попробуем проследить состояние соединения с интернетом и как идут пакеты.

Начнём с centralRouter.

Установим traceroute `yum install -y epel-release traceroute`. 
Запустим команду ping чтобы понять что выход в интернет есть и traceroute.


```
$ sudo yum install epel-release traceroute

$ ping -c 4 kernel.org
PING kernel.org (139.178.84.217) 56(84) bytes of data.
64 bytes from dfw.source.kernel.org (139.178.84.217): icmp_seq=1 ttl=61 time=142 ms
64 bytes from dfw.source.kernel.org (139.178.84.217): icmp_seq=2 ttl=61 time=142 ms
64 bytes from dfw.source.kernel.org (139.178.84.217): icmp_seq=3 ttl=61 time=142 ms
64 bytes from dfw.source.kernel.org (139.178.84.217): icmp_seq=4 ttl=61 time=142 ms

--- kernel.org ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3006ms
rtt min/avg/max/mdev = 142.614/142.741/142.858/0.387 ms

$ traceroute kernel.org
traceroute to kernel.org (139.178.84.217), 30 hops max, 60 byte packets
 1  gateway (192.168.255.1)  0.208 ms  0.194 ms  0.151 ms
 2  * * *
 3  * * *
19  dfw.source.kernel.org (139.178.84.217)  142.992 ms *  142.915 ms
```
Видим что соединение с интернетом есть и пакеты идут через `gateway (192.168.255.1)`.


Проверим то же самое на centralServer.
```
$ ping -c 4 kernel.org
PING kernel.org (139.178.84.217) 56(84) bytes of data.

--- kernel.org ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 3002ms

$ ping -c 4 192.168.255.1
PING 192.168.255.1 (192.168.255.1) 56(84) bytes of data.

--- 192.168.255.1 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 3001ms

```
Видим что соединение с интернетом нет. Так же мы не можем достучаться до inetRouter. 
Скорее всего проблема на стороне centralRoute, который не перенапраляет трафик.

После того как я поставил программу tcpdump на inetHost и centralRouter, я делал ping с centralServer и онаружил что

1. centralRouter не перенаправляет пакеты обратно. 
    Не смотря на то что в provisioning есть строчка `sysctl net.ipv4.conf.all.forwarding=1`, если мы выполним команду `sysctl net.ipv4.conf.all.forwarding` она вернёт 0.
    Такое происходит потому что эта настройка имеет временный эффект и если перезагрузить службу `network` то значение скинется на 0.
    Нужно использовать альтернативный вариант установки 'net.ipv4.conf.all.forwarding'. Нужно сделать для каждого роутера следующее.
    ```
    echo -e 'net.ipv4.conf.all.forwarding=1' > /etc/sysctl.d/99-override.conf;
    systemctl restart network
    ```
   
    После исправления проблему `ping 192.168.255.1` начал прооходить, а вот `ping kernel.org` нет.

2. inetRouter не может отправить трафик из интернета обратно хосту, который его запрашивает т.к. не настроен route.
    Лечится командой `echo "192.168.0.0/16 via 192.168.255.2" > /etc/sysconfig/network-scripts/route-eth1; systemctl restart network`
    Альтернативная команда `ip route add 192.168.0.0/16 via 192.168.255.2`.
    После применения таких исправлений `ping kernel.org` запущенный на машине centralServer проходит.


##### Подключаем офисы

Итак. Мы настроили связанность машин centralRouter, centralServer, inetRouter. Осталось сконфигурировать машины

Так же как мы добавляли route для перенаправления от inetRouter к centralRouter, нужно еще добавить в centralRouter перенаправления для office1Router,office2Router.

```
# office1
echo -e '192.168.2.0/24 via 192.168.255.5' > /etc/sysconfig/network-scripts/route-eth2
# office2
echo -e '192.168.1.0/24 via 192.168.255.9' > /etc/sysconfig/network-scripts/route-eth3
```

Альтернативный вариант выполнить команты
```shell
# centralRouter
ip route add 192.168.2.0/24 via 192.168.255.5
ip route add 192.168.1.0/24 via 192.168.255.9
```

На office1Route проверим роуты с помощью traceroute
```
$ traceroute ya.ru
traceroute to ya.ru (87.250.250.242), 30 hops max, 60 byte packets
 1  gateway (192.168.255.5)  0.252 ms  0.237 ms  0.228 ms
 2  192.168.255.1 (192.168.255.1)  0.350 ms  0.320 ms  0.295 ms
 3  * * *
10  * * *
11  ya.ru (87.250.250.242)  7.390 ms  10.885 ms  7.370 ms
```
Видим путь трафика `centralRouter -> inetRouter -> internet`.

Осталось проверить доступ office1Server и office2Server к интернету с помощью команды `ping ya.ru`.
Я проверил. Оно работает!


