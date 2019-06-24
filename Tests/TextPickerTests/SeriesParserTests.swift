//
//  ParserCreatorTests.swift
//  TextPickerTests
//
//  Created by Kåre Morstøl on 18/05/2018.
//

import TextPicker
import XCTest

class SeriesParserTests: XCTestCase {
	func testSeriesParserSimple() throws {
		assertParseAll(
			try Patterns(verify:
				Literal("a").repeat(min: 0, max: 1),
				Literal("b")),
			input: "ibiiiiabiii", count: 2)
		assertParseAll(
			try Patterns(verify:
				Literal("a").repeat(min: 0, max: 1),
				Literal("b")),
			input: "ibiiaiiababiibi", count: 4)
		assertParseAll(
			try Patterns(verify:
				Literal("b"),
				Literal("a").repeat(min: 0, max: 1)),
			input: "ibiiiibaiii", count: 2)

		let p = try Patterns(verify:
			Literal("ab"),
			OneOf(digits),
			Literal("."))
		assertParseAll(p, input: "$#%/ab8.lsgj", result: "ab8.", count: 1)
		assertParseAll(p, input: "$ab#%/ab8.lsgab3.j", count: 2)
		assertParseAll(p, input: "$#%/ab8lsgj", count: 0)
	}

	func testSeriesParserWithSkip() throws {
		let text = "This is a test text."
		assertParseAll(
			try Patterns(verify:
				Literal(" "),
				Patterns.Skip(),
				Literal(" ")),
			input: text, result: [" is ", " test "])

		/*
		 assertParseAll(
		 try SeriesParser(verify:
		 SubstringParser(" "),
		 SeriesParser.Skip(),
		 SubstringParser("d")),
		 input: " ab cd", result: [" cd"])

		 assertParseAll(
		 try SeriesParser(verify:
		 SubstringParser(" "),
		 OneOfParser(Group(contentsOf: " ").inverted()).repeat(min: 1),
		 SubstringParser("d")),
		 input: " ab cd", result: [" cd"])
		 */
	}

	func testSeriesParserWithRepeat() throws {
		let text = "This is 4 6 a test 123 text."
		assertParseAll(
			try Patterns(verify:
				Literal(" "),
				OneOf.wholeNumber.repeat(min: 0),
				Literal(" ")),
			input: text, result: [" 4 ", " 123 "])
		assertParseAll(
			try Patterns(verify:
				Literal(" "),
				Patterns.Bound(),
				OneOf.wholeNumber.repeat(min: 0),
				Patterns.Bound(),
				Literal(" ")),
			input: text, result: ["4", "6", "123"])
	}

	func testSeriesParserWithBounds() throws {
		assertParseAll(
			try Patterns(verify:
				Patterns.Bound(), Literal("a")),
			input: "xaa xa", result: "", count: 3)
		assertParseAll(
			try Patterns(verify:
				try Patterns(verify:
					Literal("x"), Patterns.Bound(), Literal("a")),
				Literal("a")),
			input: "xaxa xa", count: 3)

		let text = "This is a test text."
		assertParseAll(
			try Patterns(verify:
				Literal(" "),
				Patterns.Bound(),
				OneOf(letters).repeat(min: 1),
				Patterns.Bound(),
				Literal(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try Patterns(verify: OneOf(letters).repeat(min: 1)),
			input: text, result: ["This", "is", "a", "test", "text"])
		assertParseAll(
			try Patterns(verify:
				OneOf(letters),
				Patterns.Bound(),
				Patterns.Bound(),
				Literal(" ")),
			input: text, result: "", count: 4)
	}

	func testRepeatOrThenEndOfLine() throws {
		assertParseAll(
			try Patterns(verify:
				(OneOf.alphanumeric || OneOf(contentsOf: " ")).repeat(min: 0),
				EndOfLineParser()),
			input: "FMA026712 TECNOAUTOMOTRIZ ATLACOMULCO S",
			result: ["FMA026712 TECNOAUTOMOTRIZ ATLACOMULCO S"])
	}

	func testSeriesParserWithSkipAndBounds() throws {
		let text = "This is a test text."
		assertParseAll(
			try Patterns(verify:
				Literal(" "),
				Patterns.Bound(),
				OneOf(letters),
				Patterns.Skip(),
				Patterns.Bound(),
				Literal(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try Patterns(verify:
				Literal(" "),
				Patterns.Bound(),
				Patterns.Skip(),
				OneOf(letters),
				Patterns.Bound(),
				Literal(" ")),
			input: text, result: ["a"])
		assertParseAll(
			try Patterns(verify:
				Literal(" "),
				Patterns.Bound(),
				Patterns.Skip(),
				Patterns.Bound(),
				Literal(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try Patterns(verify:
				Literal(" "),
				Patterns.Bound(),
				Patterns.Skip(),
				Patterns.Bound()),
			input: text, result: ["is a test text."])
	}

	func testSkipWithRepeatingParser() throws {
		let text = """
		yes (a)
		yes (aaaaa)
		no (aaabaa)
		no (woieru
		lkjfd)
		yes ()
		"""

		assertParseAll(
			try Patterns(verify:
				Literal("("),
				Patterns.Skip(whileRepeating: Literal("a")),
				Literal(")")),
			input: text, result: ["(a)", "(aaaaa)", "()"])
		assertParseAll(
			try Patterns(verify:
				Literal("("),
				Patterns.Bound(),
				Patterns.Skip(whileRepeating: Literal("a")),
				Patterns.Bound(),
				Literal(")")),
			input: text, result: ["a", "aaaaa", ""])
		assertParseAll(
			try Patterns(verify:
				Literal("("),
				Patterns.Skip(whileRepeating: OneOf.newline.not),
				Literal(")")),
			input: text, result: ["(a)", "(aaaaa)", "(aaabaa)", "()"])
	}

	func testMatchBeginningOfLines() throws {
		let text = """
		airs
		blip
		cera user
		dilled10 io
		"""
		let parser = try Patterns(verify: BeginningOfLineParser(), Patterns.Bound())
		let m = Array(parser.matches(in: text[...]))

		XCTAssertEqual(m.map { text[$0.marks[0]] }, ["a", "b", "c", "d"].map(Character.init))
		XCTAssertEqual(parser.matches(in: "\n\n").map { $0.marks[0] }.count, 3)
	}

	func testMatchEndOfLines() throws {
		let text = """
		airs
		blip
		cera user
		dilled10 io

		"""
		var parser = try Patterns(verify: EndOfLineParser(), Patterns.Bound())
		var m = Array(parser.matches(in: text[...]))
		XCTAssertEqual(m.dropLast().map { text[$0.marks[0]] }, Array(repeating: Character("\n"), count: 4))

		parser = try Patterns(verify: Patterns.Bound(), EndOfLineParser())
		m = Array(parser.matches(in: text[...]))
		XCTAssertEqual(m.dropLast().map { text[$0.marks[0]] }, Array(repeating: Character("\n"), count: 4))
	}
}

extension SeriesParserTests {
	public static var allTests = [
		("testSeriesParserSimple", testSeriesParserSimple),
		("testSeriesParserWithSkip", testSeriesParserWithSkip),
		("testSeriesParserWithRepeat", testSeriesParserWithRepeat),
		("testSeriesParserWithBounds", testSeriesParserWithBounds),
		("testRepeatOrThenEndOfLine", testRepeatOrThenEndOfLine),
		("testSeriesParserWithSkipAndBounds", testSeriesParserWithSkipAndBounds),
		("testSkipWithRepeatingParser", testSkipWithRepeatingParser),
		("testMatchBeginningOfLines", testMatchBeginningOfLines),
		("testMatchEndOfLines", testMatchEndOfLines),
	]
}
