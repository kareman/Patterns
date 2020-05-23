//
//  PerformanceTests.swift
//  PatternsTests
//
//  Created by Kåre Morstøl on 31/05/2019.
//

import Patterns
import XCTest

// Note: the hits parameter to speedTest doesn't necessarily mean the _correct_ number of hits.
// It's just there to notify us when the number of hits changes.

class PerformanceTests: XCTestCase {
	func speedTest(_ pattern: Parser, testFile: String = "Long.txt", textFraction: Int = 1, hits: Int, file: StaticString = #file, line: UInt = #line) throws {
		let fulltext = try String(contentsOf: getLocalURL(for: testFile))
		let text = fulltext.prefix(fulltext.count / textFraction)
		var result = 0
		let block = {
			result = pattern.matches(in: text).reduce(into: 0) { c, _ in c += 1 }
		}
		#if DEBUG
		block()
		#else
		self.measure(block)
		#endif
		XCTAssertEqual(result, hits, file: file, line: line)
	}

	func testWordBoundary() throws {
		let pattern = try Parser(Word.boundary)
		try speedTest(pattern, textFraction: 16, hits: 79081)
	}

	func testWordBoundaryManyLanguages() throws {
		let pattern = try Parser(Word.boundary)
		try speedTest(pattern, testFile: "Multi-language-short.txt", hits: 49801)
	}

	func testUppercaseWord() throws {
		let pattern = try Parser(Word.boundary • uppercase+ • Word.boundary)
		try speedTest(pattern, textFraction: 8, hits: 887)
	}

	func testLine() throws {
		let pattern = try Parser(Line.start • Capture(Skip()) • Line.end)
		try speedTest(pattern, textFraction: 6, hits: 2550)
	}

	func testNotNewLine() throws {
		let any = OneOf(description: "any", contains: { _ in true })
		let pattern = try Parser(
			"," • Capture(Skip(whileRepeating: any - newline)) • Line.end)
		try speedTest(pattern, textFraction: 8, hits: 1413)
	}

	func testLiteralSearch() throws {
		let pattern = try Parser(Literal("Prince"))
		try speedTest(pattern, textFraction: 1, hits: 2168)
	}

	func testNonExistentLiteralSearch() throws {
		let pattern = try Parser("\n" • Skip() • "DOESN'T EXIST")
		try speedTest(pattern, textFraction: 60, hits: 0)
	}

	func testOptionalStringFollowedByNonOptionalString() throws {
		let pattern = try Parser(Literal("\"")¿ • "I")
		try speedTest(pattern, textFraction: 8, hits: 1136)
	}

	func testOneOrMore() throws {
		let pattern = try Parser(Capture(ascii+))
		try speedTest(pattern, textFraction: 8, hits: 6041)
	}

	func testSkipping1() throws {
		// [ word.boundary ] * " " * ":" * " " * " " * " " * "{" * Line.end
		let pattern = try Parser(Skip() • "." • Skip() • " " • Skip() • " ")
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

		let digits = digit+
		let pattern = try Parser(
			OneOf("+-")¿
				• (digits • ("." • digits)¿)
				/
				("." • digits)
				• (OneOf("eE") • OneOf("+-")¿ • digits)¿)
		try speedTest(pattern, textFraction: 16, hits: 11)
	}

	func testContainsClosure() throws {
		let pattern = try Parser(Word.boundary • (alphanumeric / symbol))
		try speedTest(pattern, textFraction: 16, hits: 35643)
	}
}

func getLocalURL(for path: String, file: String = #file) -> URL {
	return URL(fileURLWithPath: file)
		.deletingLastPathComponent().appendingPathComponent(path)
}
