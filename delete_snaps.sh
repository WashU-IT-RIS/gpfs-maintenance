#!/bin/bash

set -x

. setup_perl.sh

perl -cw delete_snaps.pl || exit 1

./delete_snaps.pl "$@"

