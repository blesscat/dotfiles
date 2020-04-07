#!/usr/bin/env bash
set -o errexit -o pipefail -o nounset
. "$(dirname "$0")/common.sh"

VIM_DIR="$HOME/.vim"
if [ ! -d "$VIM_DIR/autoload/plug.vim" ]; then
    curl -fLo $VIM_DIR/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

vim +PlugInstall +qall

mkdir -p ~/.vim/.undo && mkdir -p ~/.vim/.backup && mkdir -p ~/.vim/.swp
