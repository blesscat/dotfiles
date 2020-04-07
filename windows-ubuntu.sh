#before
set +x

sudo apt update
sudo apt install -y openssh-server
ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""
sudo ssh-keygen -A
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config

sudo service ssh --full-restart


# apt-get package
sudo apt install -y mosh
sudo apt install -y jq
sudo apt install -y cmake
sudo apt install -y tig
sudo apt install -y python3-dev
sudo apt install -y build-essential

sudo apt install -y neovim
# vim-plug


# after
#vim
mkdir -p ~/.vim/.undo && mkdir -p ~/.vim/.backup && mkdir -p ~/.vim/.swp

curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

nvim -c "PlugInstall" -c q -c q
bash -c "cd ~/.vim/plugged/YouCompleteMe && ./install.py --clang-completer"


