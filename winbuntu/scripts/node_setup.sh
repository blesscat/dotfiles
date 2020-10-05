#!/bin/bash
set -o errexit -o pipefail -o nounset

echo "Updating npm dependencies."
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g npm
sudo npm install -g yarn
