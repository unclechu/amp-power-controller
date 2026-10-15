#! /usr/bin/env bash
set -o errexit || exit; set -o errtrace; set -o nounset; set -o pipefail

set -o xtrace

exec 3<>/dev/ttyACM0

# Configure the already-open serial port.
stty raw -echo <&3

printf 'AMP_%s\n' "${1^^}" >&3
printf 'FAN_%s\n' "${1^^}" >&3

exec 3>&-
echo DONE
