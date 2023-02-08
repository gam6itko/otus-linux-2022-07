#!/bin/bash

# копируем с сервера на host
vagrant ssh ras_server -c "sudo cat /etc/openvpn/pki/ca.crt"             > ./ca.crt
vagrant ssh ras_server -c "sudo cat /etc/openvpn/pki/issued/client.crt"  > ./client.crt
vagrant ssh ras_server -c "sudo cat /etc/openvpn/pki/private/client.key" > ./client.key
