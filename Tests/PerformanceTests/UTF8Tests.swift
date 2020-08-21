//
//  File.swift
//
//
//  Created by Kåre Morstøl on 19/08/2020.
//

import Foundation
import Patterns
import XCTest

// Note: the hits parameter to speedTest doesn't necessarily mean the _correct_ number of hits.
// It's just there to notify us when the number of hits changes.

class UTF8Tests: XCTestCase {
	func speedTest(_ pattern: Parser<String.UTF8View>, testFile: String = "Long.txt", textFraction: Int = 1, hits: Int,
	               file: StaticString = #filePath, line: UInt = #line) throws {
		let fulltext = try String(contentsOf: getLocalURL(for: testFile))
		let text = String(fulltext.prefix(fulltext.count / textFraction)).utf8
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
			self.measure(metrics: [XCTCPUMetric(limitingToCurrentThread: true)], options: options, block: block)
		} else {
			self.measure(block)
		}
		#endif
		XCTAssertEqual(result, hits, file: file, line: line)
	}

	func testLine() throws {
		let pattern = try Parser<String.UTF8View>(search: Line.Start() • Capture(Skip()) • Line.End())
		try speedTest(pattern, textFraction: 2, hits: 7260)
	}

	func testNotNewLine() throws {
		let pattern = try Parser<String.UTF8View>(search: "," • Capture(Skip()) • Line.End())
		try speedTest(pattern, textFraction: 2, hits: 4933)
	}

	func testLiteralSearch() throws {
		let pattern = try Parser<String.UTF8View>(search: Literal("Prince"))
		try speedTest(pattern, textFraction: 1, hits: 2168)
	}

	func testGrammarLiteralSearch() throws {
		func any<Input>() -> OneOf<Input> { OneOf(description: "any", contains: { _ in true }) }

		let g = Grammar<String.UTF8View>()
		g.a <- Capture("Prince") / any() • g.a
		let pattern = try Parser(g)
		try speedTest(pattern, textFraction: 13, hits: 260)
	}

	func testNonExistentLiteralSearch() throws {
		let pattern = try Parser<String.UTF8View>(search: "\n" • Skip() • "DOESN'T EXIST")
		try speedTest(pattern, textFraction: 1, hits: 0)
	}

	func testOptionalStringFollowedByNonOptionalString() throws {
		let pattern = try Parser<String.UTF8View>(search: Literal("\"")¿ • "I")
		try speedTest(pattern, textFraction: 12, hits: 814)
	}

	func testSkipping1() throws {
		// [ word.boundary ] * " " * ":" * " " * " " * " " * "{" * Line.end
		let pattern = try Parser<String.UTF8View>(search: "." • Skip() • " " • Skip() • " ")
		try speedTest(pattern, textFraction: 2, hits: 13939)
	}
}
