#!/bin/bash
source utils.sh

cat ../bootstrap.json | jq -M -r '.symlinks | keys[] as $k | $k, .[$k]' |
while read -r key; read -r val; do
	[[ $key =~ nvim && -f ../symlinks/.config/nvim/init.vim ]] &&
		bash -c "mkdir -p ~/.config/nvim && cd ~/.config/nvim && ln -s ~/.cider/symlinks/.config/nvim/init.vim ." 
   	genSymlinks $key $val
done


cat ./config.json | jq -M -r '.symlinks | keys[] as $k | $k, .[$k]' |
while read -r key; read -r val; do
   	genSymlinks $key $val
done
