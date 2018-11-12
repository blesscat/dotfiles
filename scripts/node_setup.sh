#!/usr/bin/env bash
set -o errexit -o pipefail -o nounset

echo "Updating npm dependencies."
npm install -g npm
npm install -g yarn
