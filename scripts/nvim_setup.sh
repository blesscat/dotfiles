#!/bin/bash
set -o errexit -o pipefail -o nounset

python3 -m pip install --user --upgrade pynvim

mkdir -p ~/.vim/.undo && mkdir -p ~/.vim/.backup && mkdir -p ~/.vim/.swp
NVIM_DIR="$HOME/.local/share/nvim"
if [ ! -d "$NVIM_DIR/site/autoload/plug.vim" ]; then
    curl -fLo $NVIM_DIR/site/autoload/plug.vim --create-dirs \
	    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

nvim +PlugInstall +qall
nvim +CocInstall\ coc-json\ coc-tsserver\ coc-yank\ coc-pairs\ coc-highlight\ coc-git\ coc-explorer\ coc-eslint\ coc-deno\ coc-vetur\ coc-python\ coc-flutter
