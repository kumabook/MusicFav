#!/bin/bash -x

if ! diff Cartfile.resolved Carthage/Cartfile.checkout.resolved &>/dev/null; then
  echo '--- Carthage checkout ---'
  carthage checkout --no-use-binaries
  echo 'copy Cartfile.resolved to Carthage/Cartfile.checkout.resolved'
  cp Cartfile.resolved Carthage/Cartfile.checkout.resolved
  echo '--- carthage checkout success ---'
fi
