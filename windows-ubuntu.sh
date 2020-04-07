set +x

sudo apt update
sudo apt install -y openssh-server
ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""
ssh-keygen -A
service ssh --full-restart

sudo apt install -y mosh
sudo apt install -y jq
sudo apt install -y cmake
# sudo apt install -y python3-dev

sudo apt install -y neovim
# vim-plug
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

nvim -c "PlugInstall" -c q -c q
cd ~/.vim/plugged/YouCompleteMe
./install.py --clang-completer
