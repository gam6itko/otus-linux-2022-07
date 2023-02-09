#!/bin/bash

MACHINES=( "inetRouter" "centralRouter" "office1Router" "office2Router" "centralServer" "office1Server" "office2Server" )

for name in "${MACHINES[@]}"
do
  vagrant ssh $name -c "sudo systemctl restart network"
done
