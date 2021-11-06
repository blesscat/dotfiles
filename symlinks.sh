#!/bin/bash
source utils.sh

cat ./bootstrap.json | jq -M -r '.symlinks | keys[] as $k | $k, .[$k]' |
while read -r key; read -r val; do
    genSymlinks $key $val
done
