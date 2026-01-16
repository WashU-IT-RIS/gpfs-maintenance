#!/bin/bash

set -x

# pass filesystem name
FILESYSTEM=$1; shift

. setup_perl.sh

perl -cw perl_test.pl

exit 0

PERL_IMAGE=ghcr.io/washu-it-ris/ubuntu-perl:master

docker ps

docker pull $PERL_IMAGE

docker images

