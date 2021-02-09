#!/bin/bash

cat ./bootstrap.json | jq -M -r '.casks[]' |
while read -r package; do
	brew install $package
done
