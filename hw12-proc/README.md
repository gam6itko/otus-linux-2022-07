# Управление процессами

## Задание

Задания на выбор:

1. написать свою реализацию `ps ax` используя анализ /proc. 

    Результат ДЗ - рабочий скрипт который можно запустить

2. написать свою реализацию lsof 
  
    Результат ДЗ - рабочий скрипт который можно запустить

3. дописать обработчики сигналов в прилагаемом скрипте, оттестировать, приложить сам скрипт, инструкции по использованию

    Результат ДЗ - рабочий скрипт который можно запустить + инструкция по использованию и лог консоли

4. реализовать 2 конкурирующих процесса по IO. пробовать запустить с разными ionice

    Результат ДЗ - скрипт запускающий 2 процесса с разными ionice, замеряющий время выполнения и лог консоли

5. реализовать 2 конкурирующих процесса по CPU. пробовать запустить с разными nice

    Результат ДЗ - скрипт запускающий 2 процесса с разными nice и замеряющий время выполнения и лог консоли

## Полезные ссылки

- https://man7.org/linux/man-pages/man1/ps.1.html
- https://man7.org/linux/man-pages/man5/proc.5.html
- https://www.baeldung.com/linux/find-command-regex
- https://www.baeldung.com/linux/total-process-cpu-usage
- https://www.linuxshelltips.com/foreground-and-background-process-in-linux/


# 1. написать свою реализацию ps ax используя анализ /proc. 

Вывод команды `ps ax` примерно следующий:

```
$ ps ax
    PID TTY      STAT   TIME COMMAND
      1 ?        Ss     0:01 /sbin/init splash
      2 ?        S      0:00 [kthreadd]
      3 ?        I<     0:00 [rcu_gp]
      4 ?        I<     0:00 [rcu_par_gp]
      5 ?        I<     0:00 [netns]
      7 ?        I<     0:00 [kworker/0:0H-events_highpri]
      9 ?        I<     0:00 [kworker/0:1H-kblockd]
     10 ?        I<     0:00 [mm_percpu_wq]
     11 ?        S      0:00 [rcu_tasks_rude_]
     12 ?        S      0:00 [rcu_tasks_trace]
```

У нас есть 4 колонки: PID, TTY, STAT, TIME, COMAND. 
Можно схитрить и воспользоваться командой `strace ps ax` чтобы узнать к каким файлам из папки `/proc` обращается программа чтобы получить эти данные.

Видим что для каждоко процесса идет обращение к файлам:
- /proc/3/stat
- /proc/3/status
- /proc/3/cmdline

Находим все запущенные процесс с помощью команды `find /proc -maxdepth 1 -type d -regex '/proc/[0-9]+' | cut -d / -f 3`

Она находит папки даже для дочерних процессов, поэтому нам нужно отфильтровать дочерние процессы с помощью конструкции.
```shell
  # находим parent group
  pgrp=$(cat /proc/$pid/stat | cut -d ' ' -f 5)
  # если не совпадает с PID значит это дочерний процесс, а не основной
  if [[ $pgrp != $pid ]]; then
      continue
  fi
```

## PID 

Можно определить по числовому названию папки /proc/N

## TTY

Если в `/proc/PID/stat` имеется tty_nr и существует папка `/proc/PID/fd` и в неё есть файлы 0, 1, 2 то у нас есть привязанный stdin, stdout и stderr, что намекает на то что у нас есть привязанный терминал.
Осталось только отобразить на какой терминал указывает символьная ссылка `/proc/PID/fd/0`.

## STAT

В `man ps` мы видим статусы Главные и дополнительные.

```
PROCESS STATE CODES
   Here are the different values that the s, stat and state output
   specifiers (header "STAT" or "S") will display to describe the state of
   a process:

            D    uninterruptible sleep (usually IO)
            I    Idle kernel thread
            R    running or runnable (on run queue)
            S    interruptible sleep (waiting for an event to complete)
            T    stopped by job control signal
            t    stopped by debugger during the tracing
            W    paging (not valid since the 2.6.xx kernel)
            X    dead (should never be seen)
            Z    defunct ("zombie") process, terminated but not reaped by its parent
   
    For BSD formats and when the stat keyword is used, additional
    characters may be displayed:
   
            <    high-priority (not nice to other users)
            N    low-priority (nice to other users)
            L    has pages locked into memory (for real-time and custom IO)
            s    is a session leader
            l    is multi-threaded (using CLONE_THREAD, like NPTL pthreads do)
            +    is in the foreground process group
```

Чтобы получить основной статус можно воскользоватя любой из команд ниже

```shell
strings /proc/$pid/stat | cut -d ' ' -f 3
strings /proc/$pid/status | grep 'State' | cut -f 2 | cut -d ' ' -f 1
```

### <
Показывается для тех процессов у которых nice < 0 (или priority <20).

Как выяснилось:
- чем ниже priority тем процесс важнее
- чем ниже nice тем процесс важнее
- пользователь может изменять приоритет только с помощью команд nice и renice
- только суперпользователь может повышать приоритет (установить nice меньше 0)
- по-умолчанию priority=20 а nice=0. 
- priority = 20 - nice


### N

Противоположный статусу `N`. Показывается у процесса с nice > 0 (или priority >20)

### L
### s

Находим session id командой `cat /proc/$pid/stat | cut -d ' ' -f 5` и если значение совпадает с нашим PID то значит этот процесс есть лидер сессии.

### l

Получаем количество потоков `cat /proc/$pid/stat | cut -d ' ' -f 20` если оно больше 1 то ставим флаг `l`

### +

Получаем tty_nr командой `strings "/proc/$pid/stat" | cut -d ' ' -f 7` Если у процесса tty_nr больше 0 то к нему привязан терминал.

## TIME

Делаем по этой статье https://www.baeldung.com/linux/total-process-cpu-usage

## COMMAND

Берём данные из файла `/proc/PID/cmdline` если он пустой, значит это процесс ядра и нужно брать его из `/proc/PID/stat` (имя процесса)ю.




