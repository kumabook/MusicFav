#!/bin/bash

if ! diff Cartfile.resolved Carthage/Cartfile.resolved &>/dev/null; then
  echo '--- Carthage checkout ---'
  carthage checkout --no-use-binaries
  echo '--- carthage build ---'
  carthage build --platform iOS
  echo 'copy Cartfile.resolved'
  cp Cartfile.resolved Carthage
  echo '--- carthage install success ---'
fi
