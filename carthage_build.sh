#!/bin/bash

if ! diff Cartfile.resolved Carthage/Cartfile.checkout.resolved &>/dev/null; then
  echo '--- Carthage checkout ---'
  carthage checkout --no-use-binaries
  echo 'copy Cartfile.resolved to Carthage/Cartfile.checkout.resolved'
  cp Cartfile.resolved Carthage/Cartfile.checkout.resolved
  echo '--- carthage checkout success ---'
fi

if ! diff Cartfile.resolved Carthage/Cartfile.resolved &>/dev/null; then
  echo '--- carthage build ---'
  carthage build --platform iOS
  echo 'copy Cartfile.resolved'
  cp Cartfile.resolved Carthage/Cartfile.resolved
  echo '--- carthage install success ---'
fi
