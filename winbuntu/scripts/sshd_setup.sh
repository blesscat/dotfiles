#!/bin/bash

if [[ ! -f ~/.ssh/id_rsa ]]; then
	ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""
fi
sudo ssh-keygen -A
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo service ssh --full-restart
