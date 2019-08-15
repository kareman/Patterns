//
//  GeneralTests.swift
//  PatternsTests
//
//  Created by Kåre Morstøl on 31/05/2019.
//

import Patterns
import XCTest

// Note: the hits parameter to speedTest doesn't necessarily mean the _correct_ number of hits.
// It's just there to notify us when the number of hits changes.

class PerformanceTests: XCTestCase {
	func speedTest(_ pattern: Patterns, testFile: String = "Long.txt", textFraction: Int = 1, hits: Int, file: StaticString = #file, line: UInt = #line) throws {
		let fulltext = try String(contentsOf: getLocalURL(for: testFile))
		let text = fulltext.prefix(fulltext.count / textFraction)
		var result = 0
		self.measure {
			result = pattern.matches(in: text).reduce(into: 0) { c, _ in c += 1 }
		}
		XCTAssertEqual(result, hits, file: file, line: line)
	}

	func testWordBoundary() throws {
		let pattern = try Patterns(verify: Word.boundary)
		try speedTest(pattern, textFraction: 32, hits: 39270)
	}

	func testWordBoundaryManyLanguages() throws {
		let pattern = try Patterns(verify: Word.boundary)
		try speedTest(pattern, testFile: "Multi-language-short.txt", hits: 9960)
	}

	func testLine() throws {
		let pattern = try Patterns(verify: [line.start, Capture(Skip()), line.end])
		try speedTest(pattern, textFraction: 32, hits: 494)
	}

	func testNotNewLine() throws {
		let pattern = try Patterns(verify: Literal(","),
		                           Capture(Skip(whileRepeating: newline.not)),
		                           Line.End())
		try speedTest(pattern, textFraction: 32, hits: 352)
	}

	func testLiteralSearch() throws {
		let pattern = try Patterns(verify: Literal("Prince"))
		try speedTest(pattern, textFraction: 32, hits: 125)
	}

	func testNonExistentLiteralSearch() throws {
		let pattern = try Patterns(verify: Literal("\n"), Skip(), Literal("DOESN'T EXIST"))
		try speedTest(pattern, textFraction: 100, hits: 0)
	}

	func testOptionalStringFollowedByNonOptionalString() throws {
		let pattern = try Patterns(verify: Literal("\"").repeat(0 ... 1), Literal("I"))
		try speedTest(pattern, textFraction: 32, hits: 304)
	}

	func testOneOrMore() throws {
		let pattern = try Patterns(verify: Capture(ascii.repeat(1...)))
		try speedTest(pattern, textFraction: 100, hits: 407)
	}

	func testSkipping1() throws {
		// [ word.boundary ] * " " * ":" * " " * " " * " " * "{" * line.end
		let pattern = try Patterns(verify: Skip(), Literal("."), Skip(), Literal(" "), Skip(), Literal(" "))
		try speedTest(pattern, textFraction: 50, hits: 569)
	}
}

func getLocalURL(for path: String, file: String = #file) -> URL {
	return URL(fileURLWithPath: file)
		.deletingLastPathComponent().appendingPathComponent(path)
}
