#!/bin/bash

sudo apt update
sudo apt install -y jq

source scripts/linuxbrew_setup.sh
source symlinks.sh
source install_packages.sh
source install_formulas.sh
source after_script.sh
