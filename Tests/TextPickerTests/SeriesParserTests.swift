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
			try SeriesParser(verify:
				SubstringParser("a").repeat(min: 0, max: 1),
				SubstringParser("b")),
			input: "ibiiiiabiii", count: 2)
		assertParseAll(
			try SeriesParser(verify:
				SubstringParser("a").repeat(min: 0, max: 1),
				SubstringParser("b")),
			input: "ibiiaiiababiibi", count: 4)
		assertParseAll(
			try SeriesParser(verify:
				SubstringParser("b"),
				SubstringParser("a").repeat(min: 0, max: 1)),
			input: "ibiiiibaiii", count: 2)

		let p = try SeriesParser(verify:
			SubstringParser("ab"),
			OneOfParser(digits),
			SubstringParser("."))
		assertParseAll(p, input: "$#%/ab8.lsgj", result: "ab8.", count: 1)
		assertParseAll(p, input: "$ab#%/ab8.lsgab3.j", count: 2)
		assertParseAll(p, input: "$#%/ab8lsgj", count: 0)
	}

	func testSeriesParserWithSkip() throws {
		let text = "This is a test text."
		assertParseAll(
			try SeriesParser(verify:
				SubstringParser(" "),
				SeriesParser.Skip(),
				SubstringParser(" ")),
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
			try SeriesParser(verify:
				SubstringParser(" "),
				OneOfParser.wholeNumber.repeat(min: 0),
				SubstringParser(" ")),
			input: text, result: [" 4 ", " 123 "])
		assertParseAll(
			try SeriesParser(verify:
				SubstringParser(" "),
				SeriesParser.Bound(),
				OneOfParser.wholeNumber.repeat(min: 0),
				SeriesParser.Bound(),
				SubstringParser(" ")),
			input: text, result: ["4", "6", "123"])
	}

	func testSeriesParserWithBounds() throws {
		assertParseAll(
			try SeriesParser(verify:
				SeriesParser.Bound(), SubstringParser("a")),
			input: "xaa xa", result: "", count: 3)
		assertParseAll(
			try SeriesParser(verify:
				try SeriesParser(verify:
					SubstringParser("x"), SeriesParser.Bound(), SubstringParser("a")),
				SubstringParser("a")),
			input: "xaxa xa", count: 3)

		let text = "This is a test text."
		assertParseAll(
			try SeriesParser(verify:
				SubstringParser(" "),
				SeriesParser.Bound(),
				OneOfParser(letters).repeat(min: 1),
				SeriesParser.Bound(),
				SubstringParser(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try SeriesParser(verify: OneOfParser(letters).repeat(min: 1)),
			input: text, result: ["This", "is", "a", "test", "text"])
		assertParseAll(
			try SeriesParser(verify:
				OneOfParser(letters),
				SeriesParser.Bound(),
				SeriesParser.Bound(),
				SubstringParser(" ")),
			input: text, result: "", count: 4)
	}

	func testRepeatOrThenEndOfLine() throws {
		assertParseAll(
			try SeriesParser(verify:
				(OneOfParser.alphanumeric || OneOfParser(contentsOf: " ")).repeat(min: 0),
				EndOfLineParser()),
			input: "FMA026712 TECNOAUTOMOTRIZ ATLACOMULCO S",
			result: ["FMA026712 TECNOAUTOMOTRIZ ATLACOMULCO S"])
	}

	func testSeriesParserWithSkipAndBounds() throws {
		let text = "This is a test text."
		assertParseAll(
			try SeriesParser(verify:
				SubstringParser(" "),
				SeriesParser.Bound(),
				OneOfParser(letters),
				SeriesParser.Skip(),
				SeriesParser.Bound(),
				SubstringParser(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try SeriesParser(verify:
				SubstringParser(" "),
				SeriesParser.Bound(),
				SeriesParser.Skip(),
				OneOfParser(letters),
				SeriesParser.Bound(),
				SubstringParser(" ")),
			input: text, result: ["a"])
		assertParseAll(
			try SeriesParser(verify:
				SubstringParser(" "),
				SeriesParser.Bound(),
				SeriesParser.Skip(),
				SeriesParser.Bound(),
				SubstringParser(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try SeriesParser(verify:
				SubstringParser(" "),
				SeriesParser.Bound(),
				SeriesParser.Skip(),
				SeriesParser.Bound()),
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
			try SeriesParser(verify:
				SubstringParser("("),
				SeriesParser.Skip(whileRepeating: SubstringParser("a")),
				SubstringParser(")")),
			input: text, result: ["(a)", "(aaaaa)", "()"])
		assertParseAll(
			try SeriesParser(verify:
				SubstringParser("("),
				SeriesParser.Bound(),
				SeriesParser.Skip(whileRepeating: SubstringParser("a")),
				SeriesParser.Bound(),
				SubstringParser(")")),
			input: text, result: ["a", "aaaaa", ""])
		assertParseAll(
			try SeriesParser(verify:
				SubstringParser("("),
				SeriesParser.Skip(whileRepeating: OneOfParser.newline.not),
				SubstringParser(")")),
			input: text, result: ["(a)", "(aaaaa)", "(aaabaa)", "()"])
	}

	func testMatchBeginningOfLines() throws {
		let text = """
		airs
		blip
		cera user
		dilled10 io
		"""
		let parser = try SeriesParser(verify: BeginningOfLineParser(), SeriesParser.Bound())
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
		var parser = try SeriesParser(verify: EndOfLineParser(), SeriesParser.Bound())
		var m = Array(parser.matches(in: text[...]))
		XCTAssertEqual(m.dropLast().map { text[$0.marks[0]] }, Array(repeating: Character("\n"), count: 4))

		parser = try SeriesParser(verify: SeriesParser.Bound(), EndOfLineParser())
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
