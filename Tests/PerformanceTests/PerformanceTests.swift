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

	func testWordBoundary() throws {
		let pattern = Word.boundary
		try speedTest(pattern, textFraction: 32, hits: 39270)
	}

	func testWordBoundaryRegex() throws {
		let text = try String(String(contentsOf: getLocalURL(for: "Long.txt")).prefix(3_207_864 / 32))
		let parser = try NSRegularExpression(pattern: #"\b"#)

		let range = NSRange(text.startIndex ..< text.endIndex, in: text)

		var result = 0
		measure {
			result = parser.numberOfMatches(in: text, range: range)
		}
		print("Found \(result) word boundaries")
	}

	func testLine() throws {
		let pattern = try! Patterns([line.start, Bound(), Skip(), Bound(), line.end])
		try speedTest(pattern, textFraction: 32, hits: 494)
	}

	func testNotNewLine() throws {
		let pattern = try Patterns(Literal(","), Bound(),
		                           Skip(whileRepeating: newline.not),
		                           Bound(), Line.End())
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
		let pattern = try Patterns(Literal("\"").repeat(min: 0, max: 1), Literal("I"))
		try speedTest(pattern, textFraction: 32, hits: 304)
	}
}

extension PerformanceTests {
	public static var allTests = [
		("testWordBoundary", testWordBoundary),
	]
}

func getLocalURL(for path: String, file: String = #file) -> URL {
	return URL(fileURLWithPath: file)
		.deletingLastPathComponent().appendingPathComponent(path)
}
