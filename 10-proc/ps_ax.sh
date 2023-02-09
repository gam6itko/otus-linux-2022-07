#!/bin/bash

STAT_NAME=2
STAT_STATE=3
STAT_PARENT_GROUP=5
STAT_SESION_ID=6
STAT_TTY_NR=7
STAT_UTIME=14
STAT_STIME=15
STAT_PRIORITY=18
STAT_NUM_THREADS=20
STAT_START_TIME=22

PID_LIST=$(find /proc -maxdepth 1 -type d -regex '/proc/[0-9]+' | cut -d / -f 3)

echo -e "PID\tTTY\tSTAT\tTIME\tCOMMAND"

for pid in $PID_LIST; do
    if [[ ! -d "/proc/$pid" ]]; then
        continue
    fi

    # filter child threads
#    pgrp=$(cat /proc/$pid/stat | cut -d ' ' -f $STAT_PARENT_GROUP)
#    if [[ $pgrp != $pid ]]; then
#        echo "PGRP $pgrp PID $pid"
#    fi

    tty_nr=$(strings "/proc/$pid/stat" | cut -d ' ' -f $STAT_TTY_NR)
    tty='?'
    if [[ $tty_nr -gt 0 ]]; then
        if [[ -e "/proc/$pid/fd/0" ]]; then
            tty=$(readlink -f "/proc/$pid/fd/0")
        fi
    fi

    # state
    state=$(strings "/proc/$pid/stat" | cut -d ' ' -f $STAT_STATE)
    ## <
    priority=$(cat "/proc/$pid/stat" | cut -d ' ' -f $STAT_PRIORITY)
    if [[ priority -lt 20 ]]; then
        state="${state}<"
    fi
    ## N
    if [[ priority -gt 20 ]]; then
        state="${state}N"
    fi
    ## s
    if [[ $pid == $(cat /proc/$pid/stat | cut -d ' ' -f $STAT_SESION_ID) ]]; then
        state="${state}s"
    fi
    num_th=$(cat /proc/$pid/stat | cut -d ' ' -f $STAT_NUM_THREADS)
    ## l
    if [[ $num_th -gt 1 ]]; then
        state="${state}l"
    fi
    ## +
    if [[ $tty_nr -gt 0 ]]; then
        state="${state}+"
    fi

    # time
    tick_sec=$(getconf CLK_TCK)
    utime_ticks=$(strings "/proc/$pid/stat" | cut -d ' ' -f $STAT_UTIME)
    stime_ticks=$(strings "/proc/$pid/stat" | cut -d ' ' -f $STAT_STIME)
    proc_usage_sec=$(( ($utime_ticks + $stime_ticks) / $tick_sec))
    time_m=$(($proc_usage_sec / 60))
    time_s=$(($proc_usage_sec % 60))

    # cmd
    cmdline=$(cat /proc/$pid/cmdline | xargs -0 echo)
    if [[ -z $cmdline ]]; then
        cmdline=$(strings "/proc/$pid/stat" | cut -d ' ' -f $STAT_NAME | tr -s '(' '[' | tr -s ')' ']')
    fi

    echo $tty_nr
    printf "%d\t%s\t%s\t%d:%02d\t" $pid $tty $state $time_m $time_s
    echo $cmdline
done


