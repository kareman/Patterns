
import XCTest

@testable import TextPickerTests
@testable import PerformanceTests

let tests: [XCTestCaseEntry] = [
	testCase(TextPatternTests.allTests),
	testCase(PatternsTests.allTests),
	testCase(PerformanceTests.allTests),
]

XCTMain(tests)
