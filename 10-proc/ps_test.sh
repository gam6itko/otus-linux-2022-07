#!/bin/bash

STAT_STATE=3
STAT_PARENT_GROUP=5
STAT_SESION_ID=6
STAT_UTIME=15
STAT_STIME=15
STAT_PRIORITY=18
STAT_START_TIME=22



PID_LIST=$(find /proc -maxdepth 1 -type d -regex '/proc/[0-9]+' | cut -d / -f 3)

for pid in $PID_LIST; do

    if [[ ! -d "/proc/$pid" ]]; then
        continue
    fi

    tty_nr=$(strings "/proc/$pid/stat" | cut -d ' ' -f 7)
    if [[ $tty_nr -gt 0 ]]; then
        echo $pid $tty_nr
    fi

done


