#!/bin/bash

if [[ -d /etc/openvpn/pki ]]; then
  exit
fi

cd /etc/openvpn

echo "yes" | easyrsa init-pki

echo 'rasvpn' | easyrsa build-ca nopass
echo 'rasvpn' | easyrsa gen-req server nopass
echo 'yes' | easyrsa sign-req server server

easyrsa gen-dh 

openvpn --genkey --secret ta.key

echo 'client' | easyrsa gen-req client nopass
echo 'yes' | easyrsa sign-req client client

echo 'iroute 192.168.10.0 255.255.255.0' > /etc/openvpn/client/client
