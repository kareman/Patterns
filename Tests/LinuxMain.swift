
import XCTest

@testable import TextPickerTests

let tests: [XCTestCaseEntry] = [
	testCase(TextPatternTests.allTests),
	testCase(PatternsTests.allTests),
]

XCTMain(tests)
