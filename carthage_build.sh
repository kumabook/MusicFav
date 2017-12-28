#!/bin/bash

if ! diff Cartfile.resolved Carthage/Cartfile.resolved &>/dev/null; then
  echo '--- carthage build ---'
  carthage build --cache-builds --platform iOS
  echo 'copy Cartfile.resolved'
  cp Cartfile.resolved Carthage/Cartfile.resolved
  echo '--- carthage install success ---'
fi
