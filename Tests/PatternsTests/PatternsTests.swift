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
			Literal("a")¿ • "b",
			input: "ibiiiiabiii", count: 2)
		assertParseAll(
			Literal("a")¿ • Literal("b"),
			input: "ibiiaiiababiibi", count: 4)
		assertParseAll(
			"b" • Literal("a")¿,
			input: "ibiiiibaiii", count: 2)

		let p = "ab" • digit • "."
		assertParseAll(p, input: "$#%/ab8.lsgj", result: "ab8.", count: 1)
		assertParseAll(p, input: "$ab#%/ab8.lsgab3.j", count: 2)
		assertParseAll(p, input: "$#%/ab8lsgj", count: 0)
	}

	func testPatternsWithSkip() throws {
		let text = "This is a test text."
		assertParseAll(
			" " • Skip() • " ",
			input: text, result: [" is ", " test "])

		assertParseAll(
			" " • Skip() • "d",
			input: " ad d", result: [" ad", " d"])
	}

	func testPatternsWithRepeat() throws {
		let text = "This is 4 6 a test 123 text."
		assertParseAll(
			" " • digit* • " ",
			input: text, result: [" 4 ", " 123 "])
		assertParseAll(
			" " • Capture(digit*) • " ",
			input: text, result: ["4", "6", "123"])
		assertParseAll(
			digit • letter.repeat(0 ... 2),
			input: "2a 35abz2",
			result: ["2a", "3", "5ab", "2"])
	}

	func testPatternsWithBounds() throws {
		assertParseAll(
			Capture() • "a",
			input: "xaa xa", result: "", count: 3)
		assertParseAll(
			"x" • Capture() • "a",
			input: "xaxa xa", result: "", count: 3)

		let text = "This is a test text."
		assertParseAll(
			" " • Capture(letter+) • " ",
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			letter+,
			input: text, result: ["This", "is", "a", "test", "text"])
		assertParseAll(
			letter • Capture() • " ",
			input: text, result: "", count: 4)
	}

	func testRepeatOrThenEndOfLine() throws {
		assertParseAll(
			(alphanumeric / OneOf(" "))+ • Line.end,
			input: "FMA026712 TECNOAUTOMOTRIZ ATLACOMULCO S",
			result: ["FMA026712 TECNOAUTOMOTRIZ ATLACOMULCO S"])
	}

	func testPatternsWithSkipAndBounds() throws {
		let text = "This is a test text."
		assertParseAll(
			" " • Capture(letter • Skip()) • " ",
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			" " • Capture(Skip() • letter) • " ",
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			" " • Capture(Skip()) • Literal(" "),
			input: text, result: ["is", "a", "test"])

		assertParseAll(
			Line.start • Capture(Skip()) • Line.end,
			input: """
			1
			2

			3
			""",
			result: ["1", "2", "", "3"])

		// undefined (Skip at end)
		_ = try Parser(" " • Capture(Skip()))
			.matches(in: text)
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
			"("
				• Capture(Skip(ascii • !newline))
				• Line.End(),
			input: text, result: ["a)", "aaaaa)", "aaabaa)", "woieru", ")"])

		assertParseAll(
			"("
				• Skip(Literal("a"))
				• ")",
			input: text, result: ["(a)", "(aaaaa)", "()"])
		assertParseAll(
			"("
				• Capture(Skip(Literal("a")))
				• ")",
			input: text, result: ["a", "aaaaa", ""])

		assertParseAll(
			"("
				• Skip(ascii • newline.not)
				• ")",
			input: text, result: ["(a)", "(aaaaa)", "(aaabaa)", "()"])
	}

	func testMatchFullRange() throws {
		let text = """
		line 1

		line 3
		line 4

		"""

		XCTAssertEqual(try Parser(Line()).matches(in: text).map { text[$0.fullRange] },
		               ["line 1", "", "line 3", "line 4", ""])
	}

	func testMatchBeginningOfLines() throws {
		let text = """
		airs
		blip
		cera user
		dilled10 io
		"""
		let pattern = try Parser(Line.start • Capture())
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

		var pattern = try Parser(Line.end • Capture())
		var m = pattern.matches(in: text)
		XCTAssertEqual(m.dropLast().map { text[$0.captures[0].range.lowerBound] },
		               Array(repeating: Character("\n"), count: 4))

		pattern = try Parser(Capture() • Line.end)
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
		let pattern =
			Line.start • Capture(name: "word", letter+)
			• " " • Capture(name: "word", letter+)

		assertCaptures(pattern, input: text, result: twoFirstWords)

		let matches = Array(try Parser(pattern).matches(in: text))
		XCTAssertEqual(matches.map { text[$0[one: "word"]!] }, ["There", "Whose", "She", "In", "And"])
		XCTAssertEqual(matches.map { $0[multiple: "word"].map { String(text[$0]) } }, twoFirstWords)
		XCTAssertNil(matches.first![one: "not a name"])
	}

	let text = """
	# ================================================

	0005..0010    ; Common # Cc  [32] <control-0000>..<control-001F>
	002F          ; Common # Zs       SPACE
	"""

	lazy var rangeAndProperty: Parser<String> = {
		let hexNumber = Capture(name: "codePoint", hexDigit+)
		let hexRange = AnyPattern("\(hexNumber)..\(hexNumber)") / hexNumber
		return try! Parser(AnyPattern("\n\(hexRange, Skip()); \(Capture(name: "property", Skip())) "))
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

		let number = OneOf("+-")¿ • digit+
		let point = try Parser(AnyPattern("(\(Capture(name: "x", number)),\(Capture(name: "y", number)))"))

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

	func testOperatorPrecedence() throws {
		let p1 = "a" • Skip() • letter • !alphanumeric • "b"+
		XCTAssert(type(of: p1.right.left) == Skip<AnyPattern>.self)
		XCTAssert(type(of: "a" • "b" / "c" • "d")
			== OrPattern<ConcatenationPattern<Literal, Literal>, ConcatenationPattern<Literal, Literal>>.self,
		          #"`/` should have lower precedence than `•`"#)
	}
}
