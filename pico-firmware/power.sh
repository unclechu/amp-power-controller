#! /usr/bin/env bash
set -o errexit || exit; set -o errtrace; set -o nounset; set -o pipefail

if (( $# != 1 )) || ! [[ ${1^^} =~ ^(ON|OFF)$ ]]; then
  >&2 echo 'Unexpected arguments!'
  >&2 printf 'Usage: %q (ON|OFF)\n' "$0"
  exit 1
fi

SWITCH_TO=${1^^}

set -o xtrace

exec 3<>/dev/ttyACM0 # Open TTY

stty raw -echo <&3 # Configure open serial port to raw mode

printf 'AMP_%s\n' "$SWITCH_TO" >&3
printf 'FAN_%s\n' "$SWITCH_TO" >&3

exec 3>&- # Close the TTY
echo DONE
