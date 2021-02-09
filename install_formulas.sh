#!/bin/bash

cat ./bootstrap.json | jq -M -r '.formulas[]' |
while read -r formula; do
	brew install $formula
done
