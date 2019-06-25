//
//  ParserTests.swift
//  TextPicker
//
//  Created by Kåre Morstøl on 20/03/2017.
//
//

import Foundation
import TextPicker
import XCTest

let doublequote = Literal("\"")

class ParserTests: XCTestCase {
	func testLiteral() {
		assertParseAll(Literal("a"), input: "abcd", result: "a", count: 1)
		assertParseAll(Literal("b"), input: "abcdb", result: "b", count: 2)
		assertParseAll(Literal("ab"), input: "abcaba", result: "ab", count: 2)
	}

	func testOneOf() {
		assertParseAll(digit, input: "ab12c3,d4", count: 4)
	}

	func testOptional() throws {
		assertParseAll(try Patterns(verify: digit.repeat(min: 0)), input: "123abc123", count: 5)
		assertParseAll(try Patterns(verify: digit.repeat(min: 0, max: 1), letter),
		               input: "123abc", result: ["3a", "b", "c"])
	}

	func testRepeat() {
		assertParseAll(digit.repeat(min: 2), input: "123abc123", count: 2)
		assertParseAll(digit.repeat(min: 1), input: "123abc", result: "123", count: 1)
		assertParseAll(digit.repeat(min: 3), input: "123abc", result: "123", count: 1)
		assertParseAll(digit.repeat(min: 4), input: "123abc", count: 0)

		assertParseAll(digit.repeat(min: 1), input: "a123abc123d", result: "123", count: 2)
		assertParseAll(digit.repeat(min: 1), input: "123abc09d4 8", count: 4)
	}

	func testOrParser() {
		let parser: TextPattern = Literal("a") || Literal("b")
		assertParseAll(parser, input: "bcbd", result: "b", count: 2)
		assertParseAll(parser, input: "acdaa", result: "a", count: 3)
		assertParseAll(parser, input: "abcdb", count: 3)
	}

	func testLineStart() throws {
		let text = """
		line 1
		line 2
		line 3
		line 4
		"""
		let parser: TextPattern = Line.Start()
		assertParseAll(parser, input: "", result: "", count: 1)
		assertParseAll(parser, input: "\n", count: 2)
		assertParseAll(parser, input: text, result: "", count: 4)
		assertParseAll(
			try Patterns(verify: Line.Start(), Bound(), Skip(), Bound(), Literal(" ")),
			input: text, result: "line", count: 4)
		assertParseAll(
			try Patterns(verify: Line.Start(), Literal("line")),
			input: text, result: "line", count: 4)
		assertParseAll(
			try Patterns(
				verify: digit, Skip(), Line.Start(), Literal("l")),
			input: text, result: ["1\nl", "2\nl", "3\nl"])

		XCTAssertThrowsError(try Patterns(verify: [Line.Start(), Line.Start()]))
		XCTAssertThrowsError(try Patterns(verify: [Line.Start(), Bound(), Line.Start()]))
		XCTAssertThrowsError(
			try Patterns(verify: [Line.Start(), Skip(), Line.Start()]))
		XCTAssertNoThrow(try Patterns(verify: [Line.Start(), Skip(whileRepeating: alphanumeric || Literal("\n")), Line.Start()]))
	}

	func testLineEnd() throws {
		let parser: TextPattern = Line.End()
		assertParseAll(parser, input: "", result: "", count: 1)
		assertParseAll(parser, input: "\n", count: 2)
		assertParseAll(parser, input: "\n\n", count: 3)

		let text = """
		line 1
		line 2
		line 3
		line 4
		"""
		assertParseAll(parser, input: text, count: 4)
		assertParseAll(
			try Patterns(verify: Literal(" "), Bound(), Skip(), Bound(), Line.End()),
			input: text, result: ["1", "2", "3", "4"])
		assertParseAll(
			try Patterns(verify: digit, Line.End()),
			input: text, result: ["1", "2", "3", "4"])
		assertParseAll(
			try Patterns(verify: digit, Line.End(), Skip(), Literal("l")),
			input: text, result: ["1\nl", "2\nl", "3\nl"])

		XCTAssertThrowsError(try Patterns(verify: Line.End(), Line.End()))
		XCTAssertThrowsError(
			try Patterns(verify: Line.End(), Bound(), Line.End()))
		XCTAssertThrowsError(
			try Patterns(verify: Line.End(), Skip(), Line.End()))
		XCTAssertNoThrow(try Patterns(verify: [Line.End(), Skip(whileRepeating: alphanumeric || Literal("\n")), Line.End()]))

		assertParseAll(
			try Patterns(verify: Line.End()),
			input: "\n", count: 2)
	}

	func testParseFile() throws {
		let file = #file
		let text = try! String(contentsOfFile: file, encoding: .utf8)
		let startAt = text.range(of: "func testParseFile()")!.upperBound

		let parser: TextPattern = try Patterns(verify: Bound(), Literal("\tlet "), Skip(), Bound(), Literal("="))
		let ranges = parser.parseAll(text, from: startAt)

		XCTAssertEqual(ranges.count, 5)
		XCTAssertEqual(text[ranges.first!], "\tlet file "[...])
	}
}

extension ParserTests {
	public static var allTests = [
		("testLiteral", testLiteral),
		("testOneOf", testOneOf),
		("testOptional", testOptional),
		("testRepeat", testRepeat),
		("testOrParser", testOrParser),
		("testLineStart", testLineStart),
		("testLineEnd", testLineEnd),
		("testParseFile", testParseFile),
	]
}
