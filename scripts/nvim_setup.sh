#!/bin/bash
set -o errexit -o pipefail -o nounset

python3 -m pip install --user --upgrade pynvim

mkdir -p ~/.vim/.undo && mkdir -p ~/.vim/.backup && mkdir -p ~/.vim/.swp

NVIM_DIR="$HOME/.local/share/nvim"

if [[ -d $NVIM_DIR/site/pack/packer/start/packer ]]
then
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 $NVIM_DIR/site/pack/packer/start/packer.nvim
fi

nvim +PackerSync +qall
