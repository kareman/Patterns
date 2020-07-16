//
//  GeneralTests.swift
//  PatternsTests
//
//  Created by Kåre Morstøl on 31/05/2019.
//

@testable import Patterns
import XCTest

class GeneralTests: XCTestCase {
	func testRangeOf() {
		let c = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

		XCTAssertEqual(c.range(of: [4, 5, 6]), 4 ..< 7)
		XCTAssertEqual(c.range(of: [4, 5, 5]), nil)
		XCTAssertEqual(c.range(of: [0, 0, 0]), nil)
		XCTAssertEqual(c.range(of: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), nil)
		XCTAssertEqual(c.range(of: []), nil)
		XCTAssertEqual(c.range(of: [8, 9]), 8 ..< 10)
		XCTAssertEqual(c.range(of: [0]), 0 ..< 1)
		XCTAssertEqual(c[c.range(of: [0])!], [0])
	}
}
