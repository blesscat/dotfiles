#!/bin/bash

cat ./config.json | jq -M -r '.packages[]' |
while read -r package; do
	sudo apt install -y $package
done
