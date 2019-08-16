
import XCTest

@testable import PatternsTests
@testable import PerformanceTests

let tests: [XCTestCaseEntry] = [
	testCase(TextPatternTests.allTests),
	testCase(PatternsTests.allTests),
	testCase(PerformanceTests.allTests),
]

XCTMain(tests)
