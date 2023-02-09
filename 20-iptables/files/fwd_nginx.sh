#!/bin/bash

# очищаем таблицы
iptables -F
iptables -t nat -F

# перенаправляем внешний трафик для порта 8080 с enp0s8 на intnet enp0s9
iptables -A FORWARD \
  -i enp0s8 \
  -o enp0s9 \
  -p tcp --syn --dport 80 \
  -m conntrack --ctstate NEW \
  -j ACCEPT

# разрешаем перенаправление пакетов с внешнего на внутренний...
iptables -A FORWARD \
  -i enp0s8 \
  -o enp0s9 \
  -m conntrack --ctstate ESTABLISHED,RELATED \
  -j ACCEPT
# ... и обратно
iptables -A FORWARD \
  -i enp0s9 \
  -o enp0s8 \
  -m conntrack --ctstate ESTABLISHED,RELATED \
  -j ACCEPT

# перенарпавляем внешние соединения на порту с hostonly-интерфейса (enp0s8) на IP intnet-сети
iptables -t nat -A PREROUTING \
  -i enp0s8 \
  -p tcp --dport 8080 \
  -j DNAT --to-destination 192.168.61.20:80

# маскируем исходяший трафик внутренним IP
iptables -t nat -A POSTROUTING \
  -o enp0s9 \
  -p tcp --dport 80 \
  -d 192.168.61.20 \
  -j SNAT --to-source 192.168.61.30
