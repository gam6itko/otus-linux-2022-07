# ansible

### задание

Подготовить стенд на Vagrant как минимум с одним сервером. На этом сервере используя Ansible необходимо развернуть nginx со следующими условиями:

- необходимо использовать модуль yum/apt;
- конфигурационные файлы должны быть взяты из шаблона jinja2 с перемененными;
- после установки nginx должен быть в режиме enabled в systemd;
- должен быть использован notify для старта nginx после установки;
- сайт должен слушать на нестандартном порту - 8080, для этого использовать переменные в Ansible.

## полезные ссылки

- https://habr.com/ru/company/southbridge/blog/569172/
- https://docs.ansible.com/ansible/latest/scenario_guides/guide_vagrant.html
- https://docs.ansible.com/ansible/latest/getting_started/get_started_inventory.html#get-started-inventory
- https://docs.ansible.com/ansible/latest/reference_appendices/playbooks_keywords.html

## выполнение

### установка ansible на host machine

```shell
apt install python3-pip
python3 -m pip install --user ansible
```


###  

Проект будет состоять из 3х машин.
- nginx-node - содержит nginx и проксирует запрос извне на php-node по порту 8080
- php-node - содержин apache2. Php-скрипт просто подключается к удаленному mysql-server и делает простой запрос.
- mysql-node - БД, к которой подключается php-node. Для удобства мы поставили mariadb. 

С помощью следующих команд узнайм IP аднеса каждой машины и вписываем их в файл с переменными `group_vars/vagrant_nodes.yaml`
``` shell
vagrant ssh nginx_node -c "ip a | grep 192 | cut -d ' ' -f 6 | cut -d / -f 1"
vagrant ssh php_node   -c "ip a | grep 192 | cut -d ' ' -f 6 | cut -d / -f 1"
vagrant ssh mysql_node -c "ip a | grep 192 | cut -d ' ' -f 6 | cut -d / -f 1"
```

### запуск ansible

```shell
ansible all -m ping
```

При первом запуске возникла ошибка на всех нодах "Failed to connect to the host via ssh: Failed to add the host to the list of known hosts (/home/gam6itko/.ssh/known_hosts).\r\nvagrant@192.168.56.44: Permission denied (publickey,gssapi-keyex,gssapi-with-mic)."

Если запустить такую команду, то всё работает `ansible nginx_host -m ping --private-key=./.vagrant/machines/nginx_node/virtualbox/private_key`.
Я делаю вывод что нужно где-то в hosts.yaml нужно прописать путь до файла с private_key. 
Устанавливаем переменную `ansible_ssh_private_key_file` для каждого хоста.

Пробуем запустить playbook для одного хоста, который пока что только устанасливает один nginx.
```shell
ansible-playbook playbooks/nginx.yaml
```

Если всё прошло успешно, то запускаем всеобъемлющий playbook
```shell
ansible-playbook playbooks.yaml
```

### проверка

Если зайти на nginx_host:80, то отобразится приветственная страница nginx
Если зайти на nginx_host:8080, то отобразится приветственная страница apache2 с хоста php_node
Ecли зайти на nginx_host:8080/tables.php то отобразится var_dump  с именами таблиц



