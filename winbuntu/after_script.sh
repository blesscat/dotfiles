#!/bin/bash

cat ./config.json | jq -M -r '."after-scripts"[]' |
while read -r script; do
	source $script
done
