# DNS

## Задание

- взять стенд https://github.com/erlong15/vagrant-bind
- добавить еще один сервер client2
- завести в зоне dns.lab
 - `web1` - смотрит на клиент1
 - `web2` смотрит на клиент2
- завести еще одну зону `newdns.lab`
  - завести в ней запись www - смотрит на обоих клиентов
- настроить split-dns
  - client1 - видит обе зоны, но в зоне dns.lab только web1
  - client2 видит только dns.lab
- настроить все без выключения selinux

## Выполнение

Выполнялось по методичке.

После удачного поднятия машин если зайти на некоторые серверы и понять что DNS работает

ns01
```
$ host ns01.dns.lab
ns01.dns.lab has address 192.168.50.10
$ host ns02.dns.lab
ns02.dns.lab has address 192.168.50.11
$ host web1.dns.lab
web1.dns.lab has address 192.168.50.15
$ host web2.dns.lab
web2.dns.lab has address 192.168.50.16
```

client2
```
$ host ns01.dns.lab
ns01.dns.lab has address 192.168.50.10
$ host ns02.dns.lab
ns02.dns.lab has address 192.168.50.11
$ host web1.dns.lab
web1.dns.lab has address 192.168.50.15
$ host web2.dns.lab
web2.dns.lab has address 192.168.50.16
```

Внучную добавим зоны "newdns.lab" и делаем provision.

ns01
```
[root@ns01 ~]# host www.newdns.lab
www.newdns.lab has address 192.168.50.15
www.newdns.lab has address 192.168.50.16
```

client1
```
[vagrant@client ~]$ host www.newdns.lab
www.newdns.lab has address 192.168.50.15
www.newdns.lab has address 192.168.50.16
```

### Split-DNS


client1 должен видеть запись `web1.dns.lab` и не видеть запись `web2.dns.lab`.
client2 может видеть обе записи из домена dns.lab, но не должен видеть записи домена `newdns.lab`.

Поменяем конфиги в соответскме со Split-DNS

Сгенерированные ключи.
```
$ tsig-keygen
key "tsig-key" {
        algorithm hmac-sha256;
        secret "EWob8DMdMcl2I4+eCMnp8i924VWsOOo53RUHaFCKIyg=";
};

$ tsig-keygen
key "tsig-key" {
        algorithm hmac-sha256;
        secret "JJGGs8alxw/TPZi9v6bLS+o9yj6tNcPCEdv18FsxMfw=";
};
```

Вносим изменения в файлы named.conf на ns01 и ns02 и files/rndc.conf.j2.
Делаем `vagrant provision`.

Пингуем с client1
```
$ ping -c 2 www.newdns.lab
PING www.newdns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client1 (192.168.50.15): icmp_seq=1 ttl=64 time=0.007 ms
64 bytes from client1 (192.168.50.15): icmp_seq=2 ttl=64 time=0.028 ms

--- www.newdns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 0.007/0.017/0.028/0.011 ms


$ ping -c 2 web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client1 (192.168.50.15): icmp_seq=1 ttl=64 time=0.008 ms
64 bytes from client1 (192.168.50.15): icmp_seq=2 ttl=64 time=0.029 ms

--- web1.dns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1003ms
rtt min/avg/max/mdev = 0.008/0.018/0.029/0.011 ms


$ ping -c 2 web2.dns.lab
ping: web2.dns.lab: Name or service not known

```

Пингуем с client2
```
[vagrant@client2 ~]$ ping -c 2 www.newdns.lab
ping: www.newdns.lab: Name or service not known


[vagrant@client2 ~]$ ping -c 2 web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=1 ttl=64 time=0.325 ms
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=2 ttl=64 time=0.199 ms

--- web1.dns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 0.199/0.262/0.325/0.063 ms


[vagrant@client2 ~]$ ping -c 2 web2.dns.lab
PING web2.dns.lab (192.168.50.16) 56(84) bytes of data.
64 bytes from client2 (192.168.50.16): icmp_seq=1 ttl=64 time=0.007 ms
64 bytes from client2 (192.168.50.16): icmp_seq=2 ttl=64 time=0.027 ms

--- web2.dns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1003ms
rtt min/avg/max/mdev = 0.007/0.017/0.027/0.010 ms
```

Тут мы понимаем, что client2 видит всю зону dns.lab и не видит зону
newdns.lab
