#!/usr/bin/env bash

set -e

if [[ "$OSTYPE" == "darwin"* ]]; then
	xcodebuild test -scheme TextPicker-Package | xcpretty -f `xcpretty-travis-formatter`
fi
