//
//  TextPickerTests
//
//  Created by Kåre Morstøl on 18/05/2018.
//

import TextPicker
import XCTest

class PatternsTests: XCTestCase {
	func testPatternsSimple() throws {
		assertParseAll(
			try Patterns(Literal("a").repeat(min: 0, max: 1),
			             Literal("b")),
			input: "ibiiiiabiii", count: 2)
		assertParseAll(
			try Patterns(Literal("a").repeat(min: 0, max: 1),
			             Literal("b")),
			input: "ibiiaiiababiibi", count: 4)
		assertParseAll(
			try Patterns(Literal("b"),
			             Literal("a").repeat(min: 0, max: 1)),
			input: "ibiiiibaiii", count: 2)

		let p = try Patterns(Literal("ab"),
		                     digit,
		                     Literal("."))
		assertParseAll(p, input: "$#%/ab8.lsgj", result: "ab8.", count: 1)
		assertParseAll(p, input: "$ab#%/ab8.lsgab3.j", count: 2)
		assertParseAll(p, input: "$#%/ab8lsgj", count: 0)
	}

	func testPatternsWithSkip() throws {
		let text = "This is a test text."
		assertParseAll(
			try Patterns(Literal(" "),
			             Skip(),
			             Literal(" ")),
			input: text, result: [" is ", " test "])

		/*
		 assertParseAll(
		 try Patterns(verify:
		 SubstringPattern(" "),
		 Patterns.Skip(),
		 SubstringPattern("d")),
		 input: " ab cd", result: [" cd"])

		 assertParseAll(
		 try Patterns(verify:
		 SubstringPattern(" "),
		 OneOfPattern(Group(contentsOf: " ").inverted()).repeat(min: 1),
		 SubstringPattern("d")),
		 input: " ab cd", result: [" cd"])
		 */
	}

	func testPatternsWithRepeat() throws {
		let text = "This is 4 6 a test 123 text."
		assertParseAll(
			try Patterns(Literal(" "),
			             digit.repeat(min: 0),
			             Literal(" ")),
			input: text, result: [" 4 ", " 123 "])
		assertParseAll(
			try Patterns(Literal(" "),
			             Bound(),
			             digit.repeat(min: 0),
			             Bound(),
			             Literal(" ")),
			input: text, result: ["4", "6", "123"])
	}

	func testPatternsWithBounds() throws {
		assertParseAll(
			try Patterns(Bound(), Literal("a")),
			input: "xaa xa", result: "", count: 3)
		assertParseAll(
			try Patterns(try Patterns(Literal("x"), Bound(), Literal("a")),
			             Literal("a")),
			input: "xaxa xa", count: 3)

		let text = "This is a test text."
		assertParseAll(
			try Patterns(Literal(" "),
			             Bound(),
			             letter.repeat(min: 1),
			             Bound(),
			             Literal(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try Patterns(letter.repeat(min: 1)),
			input: text, result: ["This", "is", "a", "test", "text"])
		assertParseAll(
			try Patterns(letter,
			             Bound(),
			             Bound(),
			             Literal(" ")),
			input: text, result: "", count: 4)
	}

	func testRepeatOrThenEndOfLine() throws {
		assertParseAll(
			try Patterns((alphanumeric || OneOf(contentsOf: " ")).repeat(min: 0),
			             line.end),
			input: "FMA026712 TECNOAUTOMOTRIZ ATLACOMULCO S",
			result: ["FMA026712 TECNOAUTOMOTRIZ ATLACOMULCO S"])
	}

	func testPatternsWithSkipAndBounds() throws {
		let text = "This is a test text."
		assertParseAll(
			try Patterns(Literal(" "),
			             Bound(),
			             letter,
			             Skip(),
			             Bound(),
			             Literal(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try Patterns(Literal(" "),
			             Bound(),
			             Skip(),
			             letter,
			             Bound(),
			             Literal(" ")),
			input: text, result: ["a"])
		assertParseAll(
			try Patterns(Literal(" "),
			             Bound(),
			             Skip(),
			             Bound(),
			             Literal(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try Patterns(Literal(" "),
			             Bound(),
			             Skip(),
			             Bound()),
			input: text, result: ["is a test text."])
	}

	func testSkipWithRepeatingPattern() throws {
		let text = """
		yes (a)
		yes (aaaaa)
		no (aaabaa)
		no (woieru
		lkjfd)
		yes ()
		"""

		assertParseAll(
			try Patterns(Literal("("),
			             Skip(whileRepeating: Literal("a")),
			             Literal(")")),
			input: text, result: ["(a)", "(aaaaa)", "()"])
		assertParseAll(
			try Patterns(Literal("("),
			             Bound(),
			             Skip(whileRepeating: Literal("a")),
			             Bound(),
			             Literal(")")),
			input: text, result: ["a", "aaaaa", ""])
		assertParseAll(
			try Patterns(Literal("("),
			             Skip(whileRepeating: newline.not),
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
		let pattern = try Patterns(line.start, Bound())
		let m = Array(pattern.matches(in: text[...]))

		XCTAssertEqual(m.map { text[$0.marks[0]] }, ["a", "b", "c", "d"].map(Character.init))
		XCTAssertEqual(pattern.matches(in: "\n\n").map { $0.marks[0] }.count, 3)
	}

	func testMatchEndOfLines() throws {
		let text = """
		airs
		blip
		cera user
		dilled10 io

		"""
		var pattern = try Patterns(line.end, Bound())
		var m = Array(pattern.matches(in: text[...]))
		XCTAssertEqual(m.dropLast().map { text[$0.marks[0]] }, Array(repeating: Character("\n"), count: 4))

		pattern = try Patterns(Bound(), line.end)
		m = Array(pattern.matches(in: text[...]))
		XCTAssertEqual(m.dropLast().map { text[$0.marks[0]] }, Array(repeating: Character("\n"), count: 4))
	}
}

extension PatternsTests {
	public static var allTests = [
		("testPatternsSimple", testPatternsSimple),
		("testPatternsWithSkip", testPatternsWithSkip),
		("testPatternsWithRepeat", testPatternsWithRepeat),
		("testPatternsWithBounds", testPatternsWithBounds),
		("testRepeatOrThenEndOfLine", testRepeatOrThenEndOfLine),
		("testPatternsWithSkipAndBounds", testPatternsWithSkipAndBounds),
		("testSkipWithRepeatingPattern", testSkipWithRepeatingPattern),
		("testMatchBeginningOfLines", testMatchBeginningOfLines),
		("testMatchEndOfLines", testMatchEndOfLines),
	]
}
