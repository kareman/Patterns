//
//  PatternsTests
//
//  Created by Kåre Morstøl on 18/05/2018.
//

import Patterns
import XCTest

class PatternsTests: XCTestCase {
	func testPatternsSimple() throws {
		assertParseAll(
			try Patterns(verify: Literal("a").repeat(0 ... 1),
			             Literal("b")),
			input: "ibiiiiabiii", count: 2)
		assertParseAll(
			try Patterns(verify: Literal("a").repeat(0 ... 1),
			             Literal("b")),
			input: "ibiiaiiababiibi", count: 4)
		assertParseAll(
			try Patterns(verify: Literal("b"),
			             Literal("a").repeat(0 ... 1)),
			input: "ibiiiibaiii", count: 2)

		let p = try Patterns(verify: Literal("ab"),
		                     digit,
		                     Literal("."))
		assertParseAll(p, input: "$#%/ab8.lsgj", result: "ab8.", count: 1)
		assertParseAll(p, input: "$ab#%/ab8.lsgab3.j", count: 2)
		assertParseAll(p, input: "$#%/ab8lsgj", count: 0)
	}

	func testPatternsWithSkip() throws {
		let text = "This is a test text."
		assertParseAll(
			try Patterns(verify: Literal(" "),
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
			try Patterns(verify: Literal(" "),
			             digit.repeat(0...),
			             Literal(" ")),
			input: text, result: [" 4 ", " 123 "])
		assertParseAll(
			try Patterns(verify: Literal(" "),
			             Capture(
			             	digit.repeat(0...)
			             ),
			             Literal(" ")),
			input: text, result: ["4", "6", "123"])
		assertParseAll(
			try Patterns(verify: digit, letter.repeat(0 ... 2)),
			input: "2a 35abz2",
			result: ["2a", "3", "5ab", "2"])
	}

	func testPatternsWithBounds() throws {
		assertParseAll(
			try Patterns(verify: Capture(), Literal("a")),
			input: "xaa xa", result: "", count: 3)
		/* // TODO: Awaiting rewrite of Patterns inner workings.
		 assertParseAll(
		 	try Patterns(try Patterns(Literal("x"), Capture(), Literal("a")),
		 	             Literal("a")),
		 	input: "xaxa xa", count: 3)*/

		let text = "This is a test text."
		assertParseAll(
			try Patterns(verify: Literal(" "),
			             Capture(
			             	letter.repeat(1...)
			             ),
			             Literal(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try Patterns(verify: letter.repeat(1...)),
			input: text, result: ["This", "is", "a", "test", "text"])
		assertParseAll(
			try Patterns(verify: letter,
			             Capture(),
			             Literal(" ")),
			input: text, result: "", count: 4)
	}

	func testRepeatOrThenEndOfLine() throws {
		assertParseAll(
			try Patterns(verify: (alphanumeric || OneOf(" ")).repeat(1...),
			             Line.end),
			input: "FMA026712 TECNOAUTOMOTRIZ ATLACOMULCO S",
			result: ["FMA026712 TECNOAUTOMOTRIZ ATLACOMULCO S"])
	}

	func testPatternsWithSkipAndBounds() throws {
		let text = "This is a test text."
		assertParseAll(
			try Patterns(verify: Literal(" "),
			             Capture(
			             	letter,
			             	Skip()),
			             Literal(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try Patterns(verify: Literal(" "),
			             Capture(
			             	Skip(),
			             	letter),
			             Literal(" ")),
			input: text, result: ["a"])
		assertParseAll(
			try Patterns(verify: Literal(" "),
			             Capture(
			             	Skip()),
			             Literal(" ")),
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			try Patterns(verify: Literal(" "),
			             Capture(
			             	Skip())),
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
			try Patterns(verify: Literal("("),
			             Skip(whileRepeating: Literal("a")),
			             Literal(")")),
			input: text, result: ["(a)", "(aaaaa)", "()"])
		assertParseAll(
			try Patterns(verify: Literal("("),
			             Capture(
			             	Skip(whileRepeating: Literal("a"))),
			             Literal(")")),
			input: text, result: ["a", "aaaaa", ""])
		assertParseAll(
			try Patterns(verify: Literal("("),
			             Skip(whileRepeating: newline.not),
			             Literal(")")),
			input: text, result: ["(a)", "(aaaaa)", "(aaabaa)", "()"])
	}

	func testMatchFullRange() throws {
		let text = """
		line 1

		line 3
		line 4

		"""

		XCTAssertEqual(Patterns(Line()).matches(in: text).map { text[$0.fullRange] },
		               ["line 1", "", "line 3", "line 4", ""])
	}

	func testMatchBeginningOfLines() throws {
		let text = """
		airs
		blip
		cera user
		dilled10 io
		"""
		let pattern = try Patterns(verify: Line.start, Capture())
		let m = Array(pattern.matches(in: text))

		XCTAssertEqual(m.map { text[$0.captures[0].range.lowerBound] }, ["a", "b", "c", "d"].map(Character.init))
		XCTAssertEqual(pattern.matches(in: "\n\n").map { $0.captures[0] }.count, 3)
	}

	func testMatchEndOfLines() throws {
		let text = """
		airs
		blip
		cera user
		dilled10 io

		"""

		var pattern = try Patterns(verify: Line.end, Capture())
		var m = pattern.matches(in: text)
		XCTAssertEqual(m.dropLast().map { text[$0.captures[0].range.lowerBound] },
		               Array(repeating: Character("\n"), count: 4))

		pattern = try Patterns(verify: Capture(), Line.end)
		m = pattern.matches(in: text)
		XCTAssertEqual(m.dropLast().map { text[$0.captures[0].range.lowerBound] },
		               Array(repeating: Character("\n"), count: 4))
	}

	func testMultipleCaptures() throws {
		let text = """
		There was a young woman named Bright,
		Whose speed was much faster than light.
		She set out one day,
		In a relative way,
		And returned on the previous night.
		"""

		let twoFirstWords = [["There", "was"], ["Whose", "speed"], ["She", "set"], ["In", "a"], ["And", "returned"]]
		let pattern = Patterns(
			Line.start, Capture(name: "word", letter.repeat(1...)),
			Literal(" "), Capture(name: "word", letter.repeat(1...)))

		assertCaptures(pattern, input: text, result: twoFirstWords)

		let matches = Array(pattern.matches(in: text))
		XCTAssertEqual(matches.map { text[$0[one: "word"]!] }, ["There", "Whose", "She", "In", "And"])
		XCTAssertEqual(matches.map { $0[multiple: "word"].map { String(text[$0]) } }, twoFirstWords)
		XCTAssertNil(matches.first![one: "not a name"])
	}

	let text = """
	# ================================================

	0005..0010    ; Common # Cc  [32] <control-0000>..<control-001F>
	002F          ; Common # Zs       SPACE
	"""

	let rangeAndProperty: Patterns = {
		let hexNumber = Capture(name: "codePoint", hexDigit.repeat(1...))
		let hexRange = Patterns("\(hexNumber)..\(hexNumber)") || hexNumber
		return Patterns("\n\(hexRange, Skip()); \(Capture(name: "property", Skip())) ")
	}()

	func testStringInterpolation() throws {
		assertCaptures(rangeAndProperty, input: text, result: [["0005", "0010", "Common"], ["002F", "Common"]])
	}

	func testMatchDecoding() throws {
		struct Property: Decodable, Equatable {
			let codePoint: [Int]
			let property: String
			let notCaptured: String?
		}

		let matches = rangeAndProperty.matches(in: text).array()
		let property = try matches.first!.decode(Property.self, from: text)
		XCTAssertEqual(property, Property(codePoint: [5, 10], property: "Common", notCaptured: nil))

		XCTAssertThrowsError(try matches.last!.decode(Property.self, from: text))
	}

	func testPatternsDecoding() {
		struct Property: Decodable, Equatable {
			let codePoint: [String]
			let property: String
		}

		XCTAssertEqual(try rangeAndProperty.decode([Property].self, from: text),
		               [Property(codePoint: ["0005", "0010"], property: "Common"),
		                Property(codePoint: ["002F"], property: "Common")])
		XCTAssertEqual(try rangeAndProperty.decodeFirst(Property.self, from: text),
		               Property(codePoint: ["0005", "0010"], property: "Common"))
	}

	func testReadmeExample() throws {
		let text = "This is a point: (43,7), so is (0,5). But my final point is (3,-1)."

		let number = Patterns(OneOf("+-").repeat(0 ... 1), digit.repeat(1...))
		let point: Patterns = "(\(Capture(name: "x", number)),\(Capture(name: "y", number)))"

		let pointsAsSubstrings = point.matches(in: text).map { match in
			(text[match[one: "x"]!], text[match[one: "y"]!])
		}

		struct Point: Codable, Equatable {
			let x, y: Int
		}

		let points = try point.decode([Point].self, from: text)

		assertCaptures(point, input: text, result: [["43", "7"], ["0", "5"], ["3", "-1"]])
		_ = (pointsAsSubstrings, points)
	}
}
