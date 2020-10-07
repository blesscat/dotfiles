#!/bin/bash
set -o errexit -o pipefail -o nounset

mkdir -p ~/.vim/.undo && mkdir -p ~/.vim/.backup && mkdir -p ~/.vim/.swp
NVIM_DIR="$HOME/.local/share/nvim"

curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

vim +PlugInstall +qall
vim +CocInstall\ coc-json\ coc-tsserver\ coc-yank\ coc-pairs\ coc-highlight\ coc-git\ coc-explorer\ coc-eslint\ coc-deno\ coc-vetur\ coc-python
