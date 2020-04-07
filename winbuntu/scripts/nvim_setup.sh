#!/bin/bash
set -o errexit -o pipefail -o nounset

NVIM_DIR="$HOME/.local/share/nvim"
if [ ! -d "$NVIM_DIR/site/autoload/plug.vim" ]; then
    curl -fLo $NVIM_DIR/site/autoload/plug.vim --create-dirs \
	    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

nvim +PlugInstall +qall
bash -c "cd ~/.vim/plugged/YouCompleteMe && ./install.py --clang-completer"
mkdir -p ~/.vim/.undo && mkdir -p ~/.vim/.backup && mkdir -p ~/.vim/.swp
