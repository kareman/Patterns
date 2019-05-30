//
//  ParserTests.swift
//  TextPicker
//
//  Created by Kåre Morstøl on 20/03/2017.
//
//

import Foundation
import XCTest
@testable import TextPicker

let digits = OneOfParser.wholeNumber.set
let letters = OneOfParser.letter.set
let doublequote = SubstringParser("\"")

class ParserTests: XCTestCase {
	func testSubstring() {
		assertParseAll(SubstringParser("a"), input: "abcd", result: "a", count: 1)
		assertParseAll(SubstringParser("b"), input: "abcdb", result: "b", count: 2)
		assertParseAll(SubstringParser("ab"), input: "abcaba", result: "ab", count: 2)
	}

	func testOneOf() {
		assertParseAll(OneOfParser(digits), input: "ab12c3,d4", count: 4)
	}

	func testOptional() throws {
		assertParseAll(try SeriesParser(verify: OneOfParser(digits).repeat(min: 0)), input: "123abc123", count: 5)
		assertParseAll(try SeriesParser(verify: OneOfParser(digits).repeat(min: 0, max: 1), OneOfParser(letters)),
		               input: "123abc", result: ["3a", "b", "c"])
	}

	func testRepeat() {
		assertParseAll(OneOfParser(digits).repeat(min: 2), input: "123abc123", count: 2)
		assertParseAll(OneOfParser(digits).repeat(min: 1), input: "123abc", result: "123", count: 1)
		assertParseAll(OneOfParser(digits).repeat(min: 3), input: "123abc", result: "123", count: 1)
		assertParseAll(OneOfParser(digits).repeat(min: 4), input: "123abc", count: 0)

		assertParseAll(OneOfParser(digits).repeat(min: 1), input: "a123abc123d", result: "123", count: 2)
		assertParseAll(OneOfParser(digits).repeat(min: 1), input: "123abc09d4 8", count: 4)
	}

	func testOrParser() {
		let parser: Parser = SubstringParser("a") || SubstringParser("b")
		assertParseAll(parser, input: "bcbd", result: "b", count: 2)
		assertParseAll(parser, input: "acdaa", result: "a", count: 3)
		assertParseAll(parser, input: "abcdb", count: 3)
	}

	func testBeginningOfLineParser() throws {
		let text = """
			line 1
			line 2
			line 3
			line 4
			"""
		let parser: Parser = BeginningOfLineParser()
		assertParseAll(parser, input: "", result: "", count: 1)
		assertParseAll(parser, input: "\n", count: 2)
		assertParseAll(parser, input: text, result: "", count: 4)
		assertParseAll(
			try SeriesParser(verify: BeginningOfLineParser(), SeriesParser.Bound(), SeriesParser.Skip(), SeriesParser.Bound(), SubstringParser(" ")),
			input: text, result: "line", count: 4)
		assertParseAll(
			try SeriesParser(verify: BeginningOfLineParser(), SubstringParser("line")),
			input: text, result: "line", count: 4)
		assertParseAll(
			try SeriesParser(
				verify: OneOfParser(digits), SeriesParser.Skip(), BeginningOfLineParser(), SubstringParser("l")),
			input: text, result: ["1\nl", "2\nl", "3\nl"])

		XCTAssertThrowsError(try SeriesParser(verify: [BeginningOfLineParser(), BeginningOfLineParser()]))
		XCTAssertThrowsError(try SeriesParser(verify: [BeginningOfLineParser(), SeriesParser.Bound(), BeginningOfLineParser()]))
		XCTAssertThrowsError(
			try SeriesParser(verify: [BeginningOfLineParser(), SeriesParser.Skip(), BeginningOfLineParser()]))
		XCTAssertNoThrow(try SeriesParser(verify: [BeginningOfLineParser(), SeriesParser.Skip(whileRepeating: OneOfParser.alphanumeric || SubstringParser("\n")), BeginningOfLineParser()]))
	}

	func testEndOfLineParser() throws {
		let parser: Parser = EndOfLineParser()
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
			try SeriesParser(verify: SubstringParser(" "), SeriesParser.Bound(), SeriesParser.Skip(), SeriesParser.Bound(), EndOfLineParser()),
			input: text, result: ["1", "2", "3", "4"])
		assertParseAll(
			try SeriesParser(verify: OneOfParser(digits), EndOfLineParser()),
			input: text, result: ["1", "2", "3", "4"])
		assertParseAll(
			try SeriesParser(verify: OneOfParser(digits), EndOfLineParser(), SeriesParser.Skip(), SubstringParser("l")),
			input: text, result: ["1\nl", "2\nl", "3\nl"])

		XCTAssertThrowsError(try SeriesParser(verify: EndOfLineParser(), EndOfLineParser()))
		XCTAssertThrowsError(
			try SeriesParser(verify: EndOfLineParser(), SeriesParser.Bound(), EndOfLineParser()))
		XCTAssertThrowsError(
			try SeriesParser(verify: EndOfLineParser(), SeriesParser.Skip(), EndOfLineParser()))
		XCTAssertNoThrow(try SeriesParser(verify: [EndOfLineParser(), SeriesParser.Skip(whileRepeating: OneOfParser.alphanumeric || SubstringParser("\n")), EndOfLineParser()]))

		assertParseAll(
			try SeriesParser(verify: EndOfLineParser()),
			input: "\n", count: 2)
	}

	/*
	 func testLoadParser() {
	 do {
	 let manual = SeriesParser(SubstringParser("a\"b"), OneOfParser.baseParsers["decimalDigit"]!.repeat(min: 1), SubstringParser(".").repeat(min: 0, max: 5) || SubstringParser("b"))
	 XCTAssert(manual.description.contains("a\\\"b"), "Quote was not properly escaped.")
	 let opened = try loadParser(manual.description)
	 XCTAssertEqual(manual.description, opened.description)
	 } catch {
	 XCTFail(String(describing: error))
	 }
	 }
	 */

	func testParseFile() throws {
		let file = #file
		let text = try! String(contentsOfFile: file, encoding: .utf8)
		let startAt = text.range(of: "func testParseFile()")!.upperBound

		let parser: Parser = try SeriesParser(verify: SeriesParser.Bound(),	SubstringParser("\tlet "), SeriesParser.Skip() ,SeriesParser.Bound(), SubstringParser("="))
		let ranges = parser.parseAll(text, from: startAt)

		XCTAssertEqual(ranges.count, 5)
		XCTAssertEqual(text[ranges.first!], "\tlet file "[...])
	}
}

extension ParserTests {
	public static var allTests = [
		("testSubstring", testSubstring),
		("testOneOf", testOneOf),
		("testOptional", testOptional),
		("testRepeat", testRepeat),
		("testOrParser", testOrParser),
		("testBeginningOfLineParser", testBeginningOfLineParser),
		("testEndOfLineParser", testEndOfLineParser),
		// ("testLoadParser", testLoadParser),
		("testParseFile", testParseFile),
	]
}
