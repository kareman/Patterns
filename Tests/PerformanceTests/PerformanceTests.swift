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
		try speedTest(pattern, textFraction: 16, hits: 79081)
	}

	func testWordBoundaryManyLanguages() throws {
		let pattern = try Patterns(verify: Word.boundary)
		try speedTest(pattern, testFile: "Multi-language-short.txt", hits: 49801)
	}

	func testLine() throws {
		let pattern = try Patterns(verify: [Line.start, Capture(Skip()), Line.end])
		try speedTest(pattern, textFraction: 6, hits: 2550)
	}

	func skiptestNotNewLine() throws {
		let pattern = try Patterns(verify: Literal(","),
		                           Capture(Skip(whileRepeating: newline.not)),
		                           Line.End())
		try speedTest(pattern, textFraction: 8, hits: 1413)
	}

	func testLiteralSearch() throws {
		let pattern = try Patterns(verify: Literal("Prince"))
		try speedTest(pattern, textFraction: 1, hits: 2168)
	}

	func testNonExistentLiteralSearch() throws {
		let pattern = try Patterns(verify: Literal("\n"), Skip(), Literal("DOESN'T EXIST"))
		try speedTest(pattern, textFraction: 60, hits: 0)
	}

	func testOptionalStringFollowedByNonOptionalString() throws {
		let pattern = try Patterns(verify: Literal("\"").repeat(0 ... 1), Literal("I"))
		try speedTest(pattern, textFraction: 8, hits: 1136)
	}

	func testOneOrMore() throws {
		let pattern = try Patterns(verify: Capture(ascii.repeat(1...)))
		try speedTest(pattern, textFraction: 8, hits: 6041)
	}

	func testSkipping1() throws {
		// [ word.boundary ] * " " * ":" * " " * " " * " " * "{" * Line.end
		let pattern = try Patterns(verify: Skip(), Literal("."), Skip(), Literal(" "), Skip(), Literal(" "))
		try speedTest(pattern, textFraction: 6, hits: 4779)
	}

	func testAnyNumeral() throws {
		/* An advanced regular expression that matches any numeral is

		[+-]?
			(\d+(\.\d+)?)
			|
			(\.\d+)
		([eE][+-]?\d+)?
		*/

		let digits = digit.repeat(1...)
		let pattern = try Patterns(verify: OneOf("+-").repeat(0...1),
															 Patterns(digits, Patterns(Literal("."), digits).repeat(0...1))
																|| Patterns(Literal("."), digits),
															 Patterns(OneOf("eE"), OneOf("+-").repeat(0...1), digits).repeat(0...1))
		try speedTest(pattern, textFraction: 16, hits: 11)
	}

	func testContainsClosure() throws {
		let pattern = try Patterns(verify: Word.boundary, alphanumeric || OneOf(description: "isSymbol", contains: \.isSymbol))
		try speedTest(pattern, textFraction: 16, hits: 35643)
	}
}

func getLocalURL(for path: String, file: String = #file) -> URL {
	return URL(fileURLWithPath: file)
		.deletingLastPathComponent().appendingPathComponent(path)
}
