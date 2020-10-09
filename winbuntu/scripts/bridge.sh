#!/bin/bash

ip addr flush eth0
dhclient eth0

echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
