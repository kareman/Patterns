#!/usr/bin/env bash

set -e

swift run unicode_properties Sources/unicode_properties/WordBreakProperty.txt

if [[ "$OSTYPE" == "darwin"* ]]; then
	xcodebuild -version
	xcodebuild test -scheme TextPicker-Package | xcpretty -f `xcpretty-travis-formatter`
fi
