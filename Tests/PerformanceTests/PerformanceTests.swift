//
//  GeneralTests.swift
//  TextPickerTests
//
//  Created by Kåre Morstøl on 31/05/2019.
//

import TextPicker
import XCTest

class PerformanceTests: XCTestCase {
	func speedTest<P: TextPattern>(_ pattern: P, textFraction: Int = 32, hits: Int, file: StaticString = #file, line: UInt = #line) throws {
		let text = try String(contentsOf: getLocalURL(for: "Long.txt")).prefix(3_207_864 / textFraction)
		var result = 0
		self.measure {
			result = pattern.parseAllLazy(text, from: text.startIndex).reduce(into: 0) { c, _ in c += 1 }
		}
		XCTAssertEqual(result, hits, file: file, line: line)
	}

	func speedTest(_ pattern: Patterns, textFraction: Int = 32, hits: Int, file: StaticString = #file, line: UInt = #line) throws {
		let text = try String(contentsOf: getLocalURL(for: "Long.txt")).prefix(3_207_864 / textFraction)
		var result = 0
		self.measure {
			result = pattern.matches(in: text).reduce(into: 0) { c, _ in c += 1 }
		}
		XCTAssertEqual(result, hits, file: file, line: line)
	}

	func testWordBoundary() throws {
		let pattern = try Patterns(Word.boundary)
		try speedTest(pattern, textFraction: 32, hits: 39270)
	}

	func testLine() throws {
		let pattern = try Patterns([line.start, Capture(Skip()), line.end])
		try speedTest(pattern, textFraction: 32, hits: 494)
	}

	func testNotNewLine() throws {
		let pattern = try Patterns(Literal(","),
		                           Capture(Skip(whileRepeating: newline.not)),
		                           Line.End())
		try speedTest(pattern, textFraction: 32, hits: 352)
	}

	func testLiteralSearch() throws {
		let pattern = try Patterns(Literal("Prince"))
		try speedTest(pattern, textFraction: 32, hits: 125)
	}

	func testNonExistentLiteralSearch() throws {
		let pattern = try Patterns(Literal("\n"), Skip(), Literal("DOESN'T EXIST"))
		try speedTest(pattern, textFraction: 100, hits: 0)
	}

	func testOptionalStringFollowedByNonOptionalString() throws {
		let pattern = try Patterns(Literal("\"").repeat(0 ... 1), Literal("I"))
		try speedTest(pattern, textFraction: 32, hits: 304)
	}
}

extension PerformanceTests {
	public static var allTests = [
		("testWordBoundary", testWordBoundary),
		("testLine", testLine),
		("testNotNewLine", testNotNewLine),
		("testLiteralSearch", testLiteralSearch),
		("testNonExistentLiteralSearch", testNonExistentLiteralSearch),
		("testOptionalStringFollowedByNonOptionalString", testOptionalStringFollowedByNonOptionalString),
	]
}

func getLocalURL(for path: String, file: String = #file) -> URL {
	return URL(fileURLWithPath: file)
		.deletingLastPathComponent().appendingPathComponent(path)
}
