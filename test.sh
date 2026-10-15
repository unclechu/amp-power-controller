#! /usr/bin/env bash
set -o errexit || exit; set -o errtrace; set -o nounset; set -o pipefail

set -o xtrace

exec 3<>/dev/ttyACM0

# Configure the already-open serial port.
stty raw -echo <&3

printf 'AMP_ON\n' >&3
sleep 2s
printf 'AMP_OFF\n' >&3

sleep 2s

printf 'FAN_ON\n' >&3
sleep 2s
printf 'FAN_OFF\n' >&3

exec 3>&-
echo DONE
