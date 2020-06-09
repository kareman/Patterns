//
//  PerformanceTests.swift
//  PatternsTests
//
//  Created by Kåre Morstøl on 31/05/2019.
//

import Foundation
import Patterns
import XCTest

// Note: the hits parameter to speedTest doesn't necessarily mean the _correct_ number of hits.
// It's just there to notify us when the number of hits changes.

class PerformanceTests: XCTestCase {
	func speedTest(_ pattern: Parser<String>, testFile: String = "Long.txt", textFraction: Int = 1, hits: Int, file: StaticString = #file, line: UInt = #line) throws {
		let fulltext = try String(contentsOf: getLocalURL(for: testFile))
		let text = String(fulltext.prefix(fulltext.count / textFraction))
		var result = 0
		let block = {
			result = pattern.matches(in: text).reduce(into: 0) { c, _ in c += 1 }
		}
		#if DEBUG
		block()
		#else
		if #available(OSX 10.15, *) {
			let options = XCTMeasureOptions()
			options.iterationCount = 10
			self.measure(metrics: [XCTCPUMetric(), XCTClockMetric()], options: options, block: block)
		} else {
			self.measure(block)
		}
		#endif
		XCTAssertEqual(result, hits, file: file, line: line)
	}

	func testWordBoundary() throws {
		let pattern = try Parser(search: Word.boundary)
		try speedTest(pattern, textFraction: 16, hits: 79081)
	}

	func testWordBoundaryManyLanguages() throws {
		let pattern = try Parser(search: Word.boundary)
		try speedTest(pattern, testFile: "Multi-language-short.txt", hits: 49801)
	}

	func testUppercaseWord() throws {
		let pattern = try Parser(search: Word.boundary • uppercase+ • Word.boundary)
		try speedTest(pattern, textFraction: 8, hits: 887)
	}

	func testLine() throws {
		let pattern = try Parser(search: Line.start • Capture(Skip()) • Line.end)
		try speedTest(pattern, textFraction: 6, hits: 2550)
	}

	func testNotNewLine() throws {
		let any = OneOf(description: "any", contains: { _ in true })
		let pattern = try Parser(
			search: "," • Capture(Skip(!newline • any)) • Line.end)
		try speedTest(pattern, textFraction: 8, hits: 1413)
	}

	func testLiteralSearch() throws {
		let pattern = try Parser(search: Literal("Prince"))
		try speedTest(pattern, textFraction: 1, hits: 2168)
	}

	func testGrammarLiteralSearch() throws {
		let g = Grammar()
		g.a <- Capture("Prince") / any • g.a
		let pattern = try Parser(g)
		try speedTest(pattern, textFraction: 13, hits: 260)
	}

	func testNonExistentLiteralSearch() throws {
		let pattern = try Parser(search: "\n" • Skip() • "DOESN'T EXIST")
		try speedTest(pattern, textFraction: 60, hits: 0)
	}

	func testOptionalStringFollowedByNonOptionalString() throws {
		let pattern = try Parser(search: Literal("\"")¿ • "I")
		try speedTest(pattern, textFraction: 8, hits: 1136)
	}

	func testOneOrMore() throws {
		let pattern = try Parser(search: Capture(ascii+))
		try speedTest(pattern, textFraction: 8, hits: 6041)
	}

	func testSkipping1() throws {
		// [ word.boundary ] * " " * ":" * " " * " " * " " * "{" * Line.end
		let pattern = try Parser(search: Skip() • "." • Skip() • " " • Skip() • " ")
		try speedTest(pattern, textFraction: 6, hits: 4779)
	}

	func testAnyNumeral() throws {
		/* An advanced regular expression that matches any numeral:
		 [+-]?
		 	(\d+(\.\d+)?)
		 	|
		 	(\.\d+)
		 ([eE][+-]?\d+)?
		 */

		let digits = digit+
		let pattern = try Parser(
			search: OneOf("+-")¿
				• (digits • ("." • digits)¿)
				/
				("." • digits)
				• (OneOf("eE") • OneOf("+-")¿ • digits)¿)
		try speedTest(pattern, textFraction: 16, hits: 11)
	}

	func testContainsClosure() throws {
		let pattern = try Parser(search: Word.boundary • (alphanumeric / symbol))
		try speedTest(pattern, textFraction: 16, hits: 35643)
	}
}

func getLocalURL(for path: String, file: String = #file) -> URL {
	URL(fileURLWithPath: file)
		.deletingLastPathComponent().appendingPathComponent(path)
}
