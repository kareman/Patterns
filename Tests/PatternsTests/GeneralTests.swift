//
//  GeneralTests.swift
//  PatternsTests
//
//  Created by Kåre Morstøl on 31/05/2019.
//

import XCTest

class CollectionsRangesOfTests: XCTestCase {
	func testRangeOf1Pattern() {
		let c = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

		XCTAssertEqual(c.ranges(of: [4, 5, 6]).first!, 4 ..< 7)
		XCTAssertEqual(c.ranges(of: [4, 5, 5]), [])
		XCTAssertEqual(c.ranges(of: [0, 0, 0]), [])
		XCTAssertEqual(c.ranges(of: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]), [])
		XCTAssertEqual(c.ranges(of: []), [])
		XCTAssertEqual(c.ranges(of: [8, 9]).first!, 8 ..< 10)
		XCTAssertEqual(c.ranges(of: [0]).count, 1)
		XCTAssertEqual(c.ranges(of: [0]).first!, 0 ..< 1)
		XCTAssertEqual(c[c.ranges(of: [0]).first!], [0])
	}

	func testRangesOfRepeatedPattern() {
		let c = [0, 1, 2, 0, 1, 0, 1, 0, 8, 0]

		XCTAssertEqual(c.ranges(of: [0, 1]), [0 ..< 2, 3 ..< 5, 5 ..< 7])
		XCTAssertEqual(c.ranges(of: [1]), [1 ..< 2, 4 ..< 5, 6 ..< 7])
	}

	func testRangesOfOverlappingPattern() {
		let c = [0, 1, 0, 1, 0, 1, 0, 1, 0]

		XCTAssertEqual(c.ranges(of: [0, 1, 0]), [0 ..< 3, 2 ..< 5, 4 ..< 7, 6 ..< 9])
		XCTAssertEqual(c.ranges(of: [1, 0, 1, 0]), [1 ..< 5, 3 ..< 7, 5 ..< 9])
	}
}

extension CollectionsRangesOfTests {
	public static var allTests = [
		("testRangeOf1Pattern", testRangeOf1Pattern),
		("testRangesOfRepeatedPattern", testRangesOfRepeatedPattern),
		("testRangesOfOverlappingPattern", testRangesOfOverlappingPattern),
	]
}
