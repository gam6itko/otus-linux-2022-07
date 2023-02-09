#!/bin/bash

GROUP='admin'
if id -nG "$PAM_USER" | grep -qw $GROUP; then
    echo "$PAM_USER belongs to $GROUP"
    exit 0
else
    echo "$PAM_USER does not belong to $GROUP"
    exit 1
fi
