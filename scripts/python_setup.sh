#!/usr/bin/env bash
set -o errexit -o pipefail -o nounset

sudo installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg -target /

export PYTHON_CONFIGURE_OPTS="--enable-framework"
pyenv install 2.7.15 --skip-existing
pyenv install 3.6.5 --skip-existing

sudo pip install six --upgrade --ignore-installed six

install_dependencies() {
    sudo pip install -U pip setuptools flake8 setuptools-rust autoflake hy yapf virtualenv http-prompt
}

pyenv global 2.7.15
install_dependencies
pyenv global 3.6.5
install_dependencies
