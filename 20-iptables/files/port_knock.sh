#!/bin/bash

# Чтобы понять что тут происходит лучше читать начиная со step1 до step4.

# очищаем таблицу
iptables -F


iptables -N pass_step_1
iptables -A pass_step_1 -p tcp -j LOG --log-prefix "[in pass_step_1] "
iptables -A pass_step_1 \
  -m recent --name IP_LIST1 --set \
  -j DROP

# добавляем новую цепочку чтобы манипулировать списком IP_LIST2
iptables -N pass_step_2
iptables -A pass_step_2 -p tcp -j LOG --log-prefix "[in pass_step_2] "
# добавляем запись в список IP_LIST2, тем самым проходим этап 2 (ждем обращение к PORT3)
iptables -A pass_step_2 \
  -m recent --name IP_LIST2 --set \
  -j DROP

# добавляем новую цепучку чтобы манипулировать списком IP_LIST3
iptables -N pass_step_3
iptables -A pass_step_3 -p tcp -j LOG --log-prefix "[in pass_step_3] "
# добавляем запись в список IP_LIST3, тем самым проходим этап 3 (ждем обращение к PORT:22)
iptables -A pass_step_3 \
  -m recent --name IP_LIST3 --set \
  -j DROP


# создание цепочка для проверки шагов
iptables -N port_knock

iptables -A port_knock -p tcp -j LOG --log-prefix "[before step4] "

# step4 - final
# `-m recent --rcheck --name IP_LIST3` проверяет есть ли IP в списке IP_LIST3
# `-m --seconds 30` Пакет считается соответствующим критерию, только если последний доступ к записи был не позднее, чем число секунд назад
iptables -A port_knock \
  -p tcp --dport 22 \
  -m conntrack --ctstate NEW \
  -m recent --rcheck --seconds 30 --name IP_LIST3 \
  -j ACCEPT

# если первая запись не прошла, то скорее всего IP в списоке нет или он был туда добавлен более 30с назад
# в связи с этим удаляем запись из списка дропаем соединение
iptables -A port_knock \
  -p tcp \
  -m conntrack --ctstate NEW \
  -m recent --name IP_LIST3 --remove \
  -j DROP

iptables -A port_knock -p tcp -j LOG --log-prefix "[before step3] "

# step 3
# те же самые проверки что и в предыдущих 2х командах, но с другими портами, списками и правилами
# елси это правило сработает то переходим на цепочку pass_step_3 чтобы там добавить IP в список IP_LIST3
iptables -A port_knock \
  -p tcp --dport 9999 \
  -m conntrack --ctstate NEW \
  -m recent --rcheck --name IP_LIST2 \
  -j pass_step_3
# если порт не тот, то удаляем IP из списка.
iptables -A port_knock \
  -p tcp \
  -m conntrack --ctstate NEW \
  -m recent --name IP_LIST2 --remove \
  -j DROP

iptables -A port_knock -p tcp -j LOG --log-prefix "[before step2] "

# step 2
# похоже на предыдущее
iptables -A port_knock \
  -p tcp --dport 8888 \
  -m conntrack --ctstate NEW \
  -m recent --rcheck --name IP_LIST1 \
  -j pass_step_2
iptables -A port_knock \
  -p tcp \
  -m conntrack --ctstate NEW \
  -m recent --name IP_LIST1 --remove \
  -j DROP

iptables -A port_knock \
  -p tcp \
  -j LOG --log-prefix "[before step1] "

# step 1
# если обращение на PORT1 просто добавляем в IP_LIST1 тем самым запускаем комбо-проверку
iptables -A port_knock \
  -p tcp --dport 7777 \
  -m conntrack --ctstate NEW \
  -j pass_step_1

# набор по-умолчанию
iptables -A INPUT -p icmp --icmp-type any -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# всё остальное переводим в цепочку port_knock
iptables -A INPUT -j port_knock

# меняем политику по-умолчанию
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
