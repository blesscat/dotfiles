#!/bin/bash

cat ./bootstrap.json | jq -M -r '."after-scripts"[]' |
while read -r script; do
	source $script
done
