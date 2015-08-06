#!/bin/sh

set -e

DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"
export DEVELOPER_DIR
xcrun -sdk macosx swiftc Shark.swift -o shark
cp shark /usr/local/bin
echo "Shark Executable moved to /usr/local/bin. You can now use it through the command-line"