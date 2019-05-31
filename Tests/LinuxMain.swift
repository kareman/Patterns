
import XCTest

@testable import TextPickerTests

let tests: [XCTestCaseEntry] = [
	testCase(ParserTests.allTests),
	testCase(SeriesParserTests.allTests),
]

XCTMain(tests)
