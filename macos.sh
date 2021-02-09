#!/bin/bash

source ./scripts/brew_setup.sh
brew install jq

source ./install_formulas.sh
source ./install_casks.sh
# source ./after_script.sh
