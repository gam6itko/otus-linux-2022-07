#!/bin/bash

yum update -y
yum install -y epel-release
yum install -y setools-console policycoreutils-python
yum install -y nginx

