#!/bin/bash

set -x

# pass filesystem name
FILESYSTEM=$1; shift

. docker_setup.sh

PERL_IMAGE=ghcr.io/washu-it-ris/ubuntu-perl:master

docker ps

docker pull $PERL_IMAGE

docker images

