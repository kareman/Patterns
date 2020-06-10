import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
	[
		testCase(PlaygroundTests.allTests),
	]
}
#endif
