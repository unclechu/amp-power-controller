#! /usr/bin/env bash
set -o errexit || exit; set -o errtrace; set -o nounset; set -o pipefail

set -o xtrace
cmake -S . -B build -G Ninja -DPICO_BOARD=pico
cmake --build build
