
import XCTest

@testable import TextPickerTests

let tests: [XCTestCaseEntry] = [
	testCase(ParserTests.allTests),
	testCase(PatternsTests.allTests),
]

XCTMain(tests)
