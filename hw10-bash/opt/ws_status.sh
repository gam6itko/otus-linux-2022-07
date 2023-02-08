#!/bin/bash

source /etc/sysconfig/ws_status.conf

EXECUTE_DT=$(date --iso-8601=seconds)
VAR_DIR="/var/lib/ws_status"
LAST_RUN_INFO_FILE="$VAR_DIR/last_run"
LOCK_FILE="$VAR_DIR/lock"

ACCESS_LOG_FILE=/var/log/nginx/default.d/access.log
ERROR_LOG_FILE=/var/log/nginx/default.d/error.log

if [[ ! -d /var/lib/ws_status ]]; then
  mkdir /var/lib/ws_status
fi

# проверка на lock file
#if [[ -f $LOCK_FILE ]]; then
#  echo "Another script instance already running"
#  exit 1
#fi
# не даём запуститься другим скриптам
touch $LOCK_FILE

#if [[ ! -f $LAST_RUN_INFO_FILE ]]; then
#  cat <<-EOF > $LAST_RUN_INFO_FILE
#ACCESS_LINE=0
#LAST_RUN_DT="$(date --iso-8601=seconds)"
#EOF
#fi

function teardown {
  rm -f $LOCK_FILE
}


# удаляем lock файл даже если пользователь остановил скрипт вручную
trap 'teardown; exit 0' SIGINT

# загружаем информацию о прошлом запуске
source $LAST_RUN_INFO_FILE

ACCESS_LINE=$((ACCESS_LINE + 1))
ERROR_LINE=$((ERROR_LINE + 1))
# номер последней строчки
LAST_ACCESS_LINE=$(wc -l < $ACCESS_LOG_FILE)
LAST_ERROR_LINE=$(wc -l < $ERROR_LOG_FILE)
#echo $ACCESS_LINE $LAST_ACCESS_LINE

# cписок IP адресов
export IP_LIST=$(awk "NR >= $ACCESS_LINE && NR <= $LAST_ACCESS_LINE" $ACCESS_LOG_FILE | cut -f 1 -d ' ' | sort | uniq -c | sort -d -r)
export URL_LIST=$(awk "NR >= $ACCESS_LINE && NR <= $LAST_ACCESS_LINE" $ACCESS_LOG_FILE | cut -f 3 -d ' ' | sort | uniq -c | sort -d -r)
export HTTP_CODE_LIST=$(awk "NR >= $ACCESS_LINE && NR <= $LAST_ACCESS_LINE" $ACCESS_LOG_FILE | cut -f 5 -d ' ' | sort | uniq -c | sort -d -r)
export ERROR_LIST=$(awk "NR >= $ERROR_LINE && NR <= $LAST_ERROR_LINE" $ERROR_LOG_FILE)

TEMPLATE_FILE=/vagrant/var/lib/ws_status/template.txt

# формируем письмо и отправляем письмо на email указанный в /etc/sysconfig/ws_status.conf
export LAST_RUN_DT
export EXECUTE_DT
export EMAIL

# сохраняем в файл чтобы иметь возможность посмотреть последнее отправленное сообщение
envsubst < $TEMPLATE_FILE > /tmp/last-email.txt

# отправляем письмо
sendmail $EMAIL < /tmp/last-email.txt


# записываем данные о последнем запуске
cat <<-EOF > $LAST_RUN_INFO_FILE
ACCESS_LINE=$LAST_ACCESS_LINE
ERROR_LINE=$LAST_ERROR_LINE
LAST_RUN_DT=$EXECUTE_DT
EOF

teardown
