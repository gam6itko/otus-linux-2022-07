# Мосты, туннели и VPN

## Задание

- Между двумя виртуалками поднять vpn в режимах tun, tap. Прочуствовать разницу.
- Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на виртуалку.

* Самостоятельно изучить, поднять ocserv и подключиться с хоста к виртуалке


## Полезные материалы

- https://losst.pro/nastrojka-openvpn-v-ubuntu


## Выполнение

Выполнение по методичке.

Поднимаем машины с помощью ansible. Копируем /etc/openvpn/static.key с server на client.

На server с помощью команды `ip a` можно обнаружить что появился новый сетевой интерфейс.
```
4: tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 100
    link/ether ea:cc:f3:35:a5:9f brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.1/24 brd 10.10.10.255 scope global tap0
       valid_lft forever preferred_lft forever
    inet6 fe80::e8cc:f3ff:fe35:a59f/64 scope link 
       valid_lft forever preferred_lft forever
```
Похожий есть и на клиенте
```
4: tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 100
    link/ether 52:04:8d:5b:40:0d brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.2/24 brd 10.10.10.255 scope global tap0
       valid_lft forever preferred_lft forever
    inet6 fe80::5004:8dff:fe5b:400d/64 scope link 
       valid_lft forever preferred_lft forever
```

Если на client запустить `ping 10.10.10.1` а на server `tcpdump -itap0`.
То на server можно увидеть что он получает пакеты.
```
20:12:44.912531 IP 10.10.10.2 > server.loc: ICMP echo request, id 23281, seq 1, length 64
20:12:44.912537 IP server.loc > 10.10.10.2: ICMP echo reply, id 23281, seq 1, length 64
```

### iperf3 для tap

На сервере запускаем `iperf3 -s`, на клиенте `iperf3 -c 10.10.10.1 -t 40 -i 5`.
По ито
```
# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  4] local 10.10.10.2 port 37486 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
[  4]   0.00-5.00   sec   169 MBytes   283 Mbits/sec  216    439 KBytes       
[  4]   5.00-10.01  sec   177 MBytes   297 Mbits/sec    7    582 KBytes       
[  4]  10.01-15.00  sec   165 MBytes   278 Mbits/sec    0    757 KBytes       
[  4]  15.00-20.01  sec   168 MBytes   281 Mbits/sec    0    899 KBytes       
[  4]  20.01-25.00  sec   171 MBytes   287 Mbits/sec    2   1.01 MBytes       
[  4]  25.00-30.01  sec   167 MBytes   280 Mbits/sec    0   1.08 MBytes       
[  4]  30.01-35.01  sec   163 MBytes   273 Mbits/sec   26    841 KBytes       
[  4]  35.01-40.00  sec   166 MBytes   278 Mbits/sec    0   1.10 MBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-40.00  sec  1.31 GBytes   282 Mbits/sec  251             sender
[  4]   0.00-40.00  sec  1.31 GBytes   282 Mbits/sec                  receiver

iperf Done.
```

На сервере поменяем `tap` на `tun` и сделаем `vagrant provision`.
```
# iperf3 -c 10.10.10.1 -t 40 -i 5
Connecting to host 10.10.10.1, port 5201
[  4] local 10.10.10.2 port 35026 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
[  4]   0.00-5.01   sec   186 MBytes   311 Mbits/sec   24    519 KBytes       
[  4]   5.01-10.01  sec   188 MBytes   315 Mbits/sec    2    583 KBytes       
[  4]  10.01-15.00  sec   190 MBytes   318 Mbits/sec    2    613 KBytes       
[  4]  15.00-20.00  sec   187 MBytes   314 Mbits/sec    4    460 KBytes       
[  4]  20.00-25.01  sec   172 MBytes   288 Mbits/sec   45    534 KBytes       
[  4]  25.01-30.00  sec   171 MBytes   287 Mbits/sec    7    584 KBytes       
[  4]  30.00-35.01  sec   173 MBytes   290 Mbits/sec    3    580 KBytes       
[  4]  35.01-40.00  sec   171 MBytes   287 Mbits/sec    2    618 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-40.00  sec  1.40 GBytes   301 Mbits/sec   89             sender
[  4]   0.00-40.00  sec  1.40 GBytes   301 Mbits/sec                  receiver

iperf Done.
```

В интеренете пишут что:
- TAP эмулирует Ethernet устройство и работает на канальном уровне (ур.2) модели OSI, оперируя кадрами Ethernet. 
- TUN (сетевой туннель) работает на сетевом уровне (ур.3) модели OSI, оперируя IP пакетами. TAP используется для создания сетевого моста, тогда как TUN для маршрутизации.

Судя по цифрам TUN может пропустить больше трафика и меньшее количество retry.


## RAS на базе OpenVPN

Создана отдельная машина ras_server. 

После удачного provisoning нужно запустить на host-machine.
```shell
cd ./ras_client
./pull_keys.sh
sudo openvpn --config client.conf
```

В логах видим следующее
```
2023-02-07 02:35:54 Outgoing Data Channel: Cipher 'AES-256-GCM' initialized with 256 bit key
2023-02-07 02:35:54 Incoming Data Channel: Cipher 'AES-256-GCM' initialized with 256 bit key
2023-02-07 02:35:54 net_route_v4_best_gw query: dst 0.0.0.0
2023-02-07 02:35:54 net_route_v4_best_gw result: via 192.168.0.1 dev enp8s0
2023-02-07 02:35:54 ROUTE_GATEWAY 192.168.0.1/255.255.255.0 IFACE=enp8s0 HWADDR=40:b0:76:5b:bf:c6
2023-02-07 02:35:54 TUN/TAP device tun0 opened
2023-02-07 02:35:54 net_iface_mtu_set: mtu 1500 for tun0
2023-02-07 02:35:54 net_iface_up: set tun0 up
2023-02-07 02:35:54 net_addr_ptp_v4_add: 10.10.10.6 peer 10.10.10.5 dev tun0
2023-02-07 02:35:54 net_route_v4_add: 192.168.62.0/24 via 10.10.10.5 dev [NULL] table 0 metric -1
2023-02-07 02:35:54 net_route_v4_add: 192.168.10.0/24 via 10.10.10.5 dev [NULL] table 0 metric -1
2023-02-07 02:35:54 net_route_v4_add: 10.10.10.0/24 via 10.10.10.5 dev [NULL] table 0 metric -1
```

В `ip a` появился новый интерфейс
```
13: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 500
    link/none 
    inet 10.10.10.6 peer 10.10.10.5/32 scope global tun0
       valid_lft forever preferred_lft forever
    inet6 fe80::83ce:be86:aca0:84d7/64 scope link stable-privacy 
       valid_lft forever preferred_lft forever
```

ip r
```
10.10.10.0/24 via 10.10.10.5 dev tun0 
10.10.10.5 dev tun0 proto kernel scope link src 10.10.10.6 
```


