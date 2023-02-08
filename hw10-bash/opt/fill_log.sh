#!/bin/bash

IP=192.168.56.10

curl -s $IP/ > /dev/null
curl -s $IP/hello > /dev/null
curl -s $IP/comrade > /dev/null
curl -s $IP/do_you > /dev/null
curl -s $IP/have > /dev/null
curl -s $IP/some/url/paths > /dev/null
curl -s $IP/for_ME > /dev/null
curl -s $IP/NO?you=do_n_T > /dev/null
