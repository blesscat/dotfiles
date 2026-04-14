#!/bin/bash

set -e

jq -r '.formulas[]' ./bootstrap.json |
while read -r formula; do
	brew install "$formula"
done
