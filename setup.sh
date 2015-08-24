#!/bin/sh

set -e

DEVELOPER_DIR=`xcode-select -p`
export DEVELOPER_DIR
xcrun -sdk macosx swiftc Shark.swift -o shark
mv shark /usr/local/bin
echo "Shark Executable moved to /usr/local/bin. You can now use it through the command-line"
