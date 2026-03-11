#!/bin/bash

export WORKSPACE=$(pwd)

#set -euo pipefail

export PERL_PREFIX="$WORKSPACE/.perl"

# Make perl look in the workspace for modules
export PERL5LIB="$PERL_PREFIX/lib/perl5${PERL5LIB:+:$PERL5LIB}"
export PATH="$PERL_PREFIX/bin:$PATH"

# Tell CPAN installers to install into the workspace prefix
export PERL_MM_OPT="INSTALL_BASE=$PERL_PREFIX"
export PERL_MB_OPT="--install_base $PERL_PREFIX"

# Bootstrap cpanminus locally (no root, no system changes)
curl -fsSL https://cpanmin.us | perl - --local-lib="$PERL_PREFIX" App::cpanminus

# Install whatever modules you need locally
#cpanm --notest --local-lib="$PERL_PREFIX" JSON LWP::UserAgent Try::Tiny

cpanm --notest --local-lib="$PERL_PREFIX" --installdeps .

set -x

SCRIPT=$1; shift

perl -cw $1 || exit 13

exec perl $SCRIPT "$@"

