#! /usr/bin/env bash
set -o errexit || exit; set -o errtrace; set -o nounset; set -o pipefail

set -o xtrace

CFLAGS=$(pkg-config --cflags jack)
LIBS=$(pkg-config --libs jack)

cc -std=c11 -O2 -Wall -Wextra -Wpedantic \
  $CFLAGS \
  amp-watch.c -o amp-watch \
  $LIBS -pthread
