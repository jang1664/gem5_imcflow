#!/usr/bin/env bash

# arch, target is first and second args. if not set use X86 and gem.opt

ARCH=$1
TARGET=$2
ARCH=${ARCH:-X86}
TARGET=${TARGET:-gem5.opt}

scons -j4 "build/${ARCH}/${TARGET}"
