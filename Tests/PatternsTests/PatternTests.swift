//
//  PatternTests.swift
//  Patterns
//
//  Created by Kåre Morstøl on 20/03/2017.
//
//

import Patterns
import XCTest

let asciiDigit = OneOf<String.UTF8View>(UInt8(ascii: "0") ... UInt8(ascii: "9"))
let asciiLowercase = OneOf<String.UTF8View>(UInt8(ascii: "a") ... UInt8(ascii: "z"))
let asciiUppercase = OneOf<String.UTF8View>(UInt8(ascii: "A") ... UInt8(ascii: "Z"))
let asciiLetter = OneOf<String.UTF8View>(asciiLowercase, asciiUppercase)

class PatternTests: XCTestCase {
	func testLiteral() {
		assertParseAll(Capture("a"), input: "abcd", result: "a", count: 1)
		assertParseAll(Capture("b"), input: "abcdb", result: "b", count: 2)
		assertParseAll(Capture("ab"), input: "abcaba", result: "ab", count: 2)
	}

	func testLiteralUTF8() {
		assertParseAll(Capture(Literal("a".utf8)), input: "abcd".utf8, result: "a".utf8, count: 1)
		assertParseAll(Capture(Literal("b".utf8)), input: "abcdb".utf8, result: "b".utf8, count: 2)
		assertParseAll(Capture(Literal("ab".utf8)), input: "abcaba".utf8, result: "ab".utf8, count: 2)
	}

	func testOneOf() {
		let vowels = OneOf("aeiouAEIOU")
		assertParseAll(Capture(vowels), input: "I am, you are", result: ["I", "a", "o", "u", "a", "e"])
		let notVowels = OneOf(not: "aeiouAEIOU")
		assertParseAll(Capture(notVowels), input: "I am, you are", result: [" ", "m", ",", " ", "y", " ", "r"])

		let lowercaseASCII = OneOf(description: "lowercaseASCII") { character in
			character.isASCII && character.isLowercase
		}
		assertParseAll(Capture(lowercaseASCII), input: "aTæøåk☀️", result: ["a", "k"])

		assertParseAll(digit, input: "ab12c3,d4", count: 4)

		assertParseAll(Capture(OneOf("a" ... "e")),
		               input: "abgkxeryza", result: ["a", "b", "e", "a"])
		assertParseAll(Capture(OneOf(not: "a" ..< "f")),
		               input: "abgkxeryza", result: ["g", "k", "x", "r", "y", "z"])
	}

	func testOneOfUTF8() {
		let vowels = OneOf("aeiouAEIOU".utf8)
		assertParseAll(Capture(vowels), input: "I am, you are".utf8, result: ["I", "a", "o", "u", "a", "e"].map { $0.utf8 })
		let notVowels = OneOf(not: "aeiouAEIOU".utf8)
		assertParseAll(Capture(notVowels), input: "I am, you are".utf8, result: [" ", "m", ",", " ", "y", " ", "r"].map { $0.utf8 })

		let lowercaseASCII = OneOf<String.UTF8View>(description: "lowercaseASCII") { character in
			(UInt8(ascii: "a") ... UInt8(ascii: "z")).contains(character)
		}
		assertParseAll(Capture(lowercaseASCII), input: "aTæøåk☀️".utf8, result: ["a", "k"].map { $0.utf8 })

		assertParseAll(Capture(OneOf<String.UTF8View>(UInt8(ascii: "a") ... UInt8(ascii: "e"))),
		               input: "abgkxeryza".utf8, result: ["a", "b", "e", "a"].map { $0.utf8 })
		assertParseAll(Capture(OneOf<String.UTF8View>(not: UInt8(ascii: "a") ..< UInt8(ascii: "f"))),
		               input: "abgkxeryza".utf8, result: ["g", "k", "x", "r", "y", "z"].map { $0.utf8 })

		// requires String.UTF8View to be ExpressibleByStringLiteral
		// assertParseAll(OneOf(".,"), input: "., ,".utf8, result: [".", ",", ","].map{$0.utf8})
	}

	func testOneOfsMultiple() {
		assertParseAll(Capture(OneOf("a" ... "e", "xyz")),
		               input: "abegkxryz", result: ["a", "b", "e", "x", "y", "z"])
		assertParseAll(Capture(OneOf("a" ..< "e", "g", uppercase)),
		               input: "aBcdefgh", result: ["a", "B", "c", "d", "g"])

		assertParseAll(Capture(OneOf(not: "a" ... "e", "xyz")),
		               input: "abegkxryz", result: ["g", "k", "r"])
		assertParseAll(Capture(OneOf(not: "a" ..< "e", "g", uppercase)),
		               input: "aBcdefgh", result: ["e", "f", "h"])
	}

	func testOptional() throws {
		assertParseAll(letter • digit*, input: "123abc123d", count: 4)
		assertParseAll(Capture(digit¿ • letter),
		               input: "123abc", result: ["3a", "b", "c"])

		assertParseAll(asciiLetter • asciiDigit*, input: "123abc123d".utf8, count: 4)
		assertParseAll(Capture(asciiDigit¿ • asciiLetter),
		               input: "123abc".utf8, result: ["3a", "b", "c"].map { $0.utf8 })
	}

	func testRepeat() throws {
		assertParseAll(digit.repeat(2...), input: "12a1bc123", count: 2)
		assertParseAll(Capture(digit+), input: "123abc", result: "123", count: 1)
		assertParseAll(Capture(digit.repeat(3...)), input: "123abc", result: "123", count: 1)
		assertParseAll(digit.repeat(4...), input: "123abc", count: 0)

		assertParseAll(Capture(digit+), input: "a123abc123d", result: "123", count: 2)
		assertParseAll(digit+, input: "123abc09d4 8", count: 4)
		assertParseAll(Capture(digit.repeat(...2) • letter),
		               input: "123abc09d4 8", result: ["23a", "b", "c", "09d"])

		assertParseAll(Capture(digit.repeat(1 ... 2)), input: "123abc09d48", result: ["12", "3", "09", "48"])

		assertParseAll(Capture(digit.repeat(2)), input: "1234 5 6 78", result: ["12", "34", "78"])

		assertParseAll(Capture("a"* • "b"), input: "b aabb ab", result: ["b", "aab", "b", "ab"])
		assertParseAll(Capture("a"*), input: "b aabb ab", result: ["", "", "aa", "", "", "", "a", "", ""])

		/* TODO: uncomment
		 assertParseAll(
		 	Capture((!newline • ascii)+),
		 	input: "123\n4567\n89", result: ["123", "4567", "89"])
		 */

		XCTAssertEqual(digit+.description, "digit{1...}")
	}

	func testRepeatLiterals() throws {
		assertParseAll(Capture("a"+), input: "a aa  aa", result: ["a", "aa", "aa"])
		assertParseAll(Capture("a"+), input: "a aa  aa".utf8, result: ["a", "aa", "aa"].map { $0.utf8 })
		assertParseAll(Capture("a" • "a"*), input: "a aaa  aa".utf16, result: ["a", "aaa", "aa"].map { $0.utf16 })
		assertParseAll(Capture("a" • "a"¿), input: "a aa  aa".unicodeScalars, result: ["a", "aa", "aa"].map { $0.unicodeScalars })
	}

	/* TODO: uncomment
	 func testOr() {
	 	let pattern = Capture("a" / "b")
	 	assertParseAll(pattern, input: "bcbd", result: "b", count: 2)
	 	assertParseAll(pattern, input: "acdaa", result: "a", count: 3)
	 	assertParseAll(pattern, input: "abcdb", count: 3)
	 }

	 func testOrWithCapture() throws {
	 	let text = """
	 	# Total code points: 88

	 	# ================================================

	 	0780..07A5    ; Thaana # Lo  [38] THAANA LETTER HAA..THAANA LETTER WAAVU
	 	07B1          ; Thaana # Lo       THAANA LETTER NAA

	 	"""

	 	let hexDigit = OneOf(description: "hexDigit", contains: {
	 		$0.unicodeScalars.first!.properties.isHexDigit
	 	})
	 	let hexNumber = Capture(hexDigit+)
	 	let hexRange = (hexNumber • ".." • hexNumber) / hexNumber
	 	let rangeAndProperty = Line.start • hexRange • Skip() • "; " • Capture(Skip()) • " "

	 	assertCaptures(rangeAndProperty, input: text,
	 	               result: [["0780", "07A5", "Thaana"], ["07B1", "Thaana"]])
	 }
	 */
	func testLineStart() throws {
		let text = """
		line 1
		line 2
		line 3
		line 4
		"""
		let pattern = Line.start
		assertParseAll(pattern, input: "", result: "", count: 1)
		assertParseAll(pattern, input: "\n", count: 2)
		assertParseAll(pattern, input: text, result: "", count: 4)
		assertParseAll(
			Line.start • Capture(Skip()) • " ",
			input: text, result: "line", count: 4)
		assertParseAll(
			Capture(Line.start • "line"),
			input: text, result: "line", count: 4)
		assertParseAll(
			Capture(digit • Skip() • Line.start • "l"),
			input: text, result: ["1\nl", "2\nl", "3\nl"])

		/* TODO: Implement?
		 XCTAssertThrowsError(Line.start • Line.start)
		 XCTAssertThrowsError(Line.start • Capture(Line.start))
		 */
		XCTAssertNoThrow(Line.start • Skip() • Line.start)
	}

	func testLineEnd() throws {
		let pattern = Line.end
		assertParseAll(pattern, input: "", result: "", count: 1)
		assertParseAll(pattern, input: "\n", count: 2)
		assertParseAll(pattern, input: "\n\n", count: 3)

		let text = """
		line 1
		line 2
		line 3
		line 4
		"""
		assertParseAll(pattern, input: text, count: 4)
		assertParseAll(
			" " • Capture(Skip()) • Line.end,
			input: text, result: ["1", "2", "3", "4"])
		assertParseAll(
			Capture(digit • Line.end),
			input: text, result: ["1", "2", "3", "4"])
		assertParseAll(
			Capture(digit • Line.end • Skip() • "l"),
			input: text, result: ["1\nl", "2\nl", "3\nl"])

		// TODO: Implement?
		// XCTAssertThrowsError(Line.end • Line.end)
		// XCTAssertThrowsError(Line.end • Capture(Line.end))

		XCTAssertNoThrow(try Parser(search: Line.end • Skip() • Line.end))

		assertParseAll(Line.end, input: "\n", count: 2)
	}

	func testLineEndUTF8_16_UnicodeScalars() throws {
		let pattern = Line<String.UTF16View>.End()
		assertParseAll(pattern, input: "".utf16, result: "".utf16, count: 1)
		assertParseAll(pattern, input: "\n".utf16, count: 2)
		assertParseAll(pattern, input: "\n\n".utf16, count: 3)

		let text = """
		line 1
		line 2
		line 3
		line 4
		""".utf8
		assertParseAll(Line.End(), input: text, count: 4)
		assertParseAll(
			" " • Capture(Skip()) • Line.End(),
			input: text, result: ["1", "2", "3", "4"].map { $0.utf8 })
		assertParseAll(
			Capture(asciiDigit • Line.End()),
			input: text, result: ["1", "2", "3", "4"].map { $0.utf8 })
		assertParseAll(
			Capture(asciiDigit • Line.End() • Skip() • "l"),
			input: text, result: ["1\nl", "2\nl", "3\nl"].map { $0.utf8 })

		assertParseAll(Line.End(), input: "\n".unicodeScalars, count: 2)
	}

	func testLine() throws {
		let text = """
		line 1

		line 3
		line 4

		"""

		assertParseAll(Capture(Line()), input: text, result: ["line 1", "", "line 3", "line 4", ""])
		assertParseAll(Capture(Line()), input: text.utf8, result: ["line 1", "", "line 3", "line 4", ""].map { $0.utf8 })
	}

	func testWordBoundary() throws {
		let pattern = Word.boundary
		assertParseMarkers(pattern, input: #"|I| |said| |"|hello|"|"#)
		assertParseMarkers(pattern, input: "|this| |I| |-|3,875.08| |can't|,| |you| |letter|-|like|.| |And|?| |then|")
	}

	func testNot() throws {
		assertParseMarkers(!alphanumeric, input: #"I| said|,| 3|"#)
		assertParseAll(
			Capture(Word.boundary • !digit • alphanumeric+),
			input: "123 abc 1ab a32b",
			result: ["abc", "a32b"])
		assertParseAll(
			Word.boundary • Capture(!digit • alphanumeric+),
			input: "123 abc 1ab a32b",
			result: ["abc", "a32b"])
		assertParseAll(
			Capture(!"abc" • letter+),
			input: "ab abc abcd efg",
			result: ["ab", "bc", "bcd", "efg"])

		func any<Input>() -> OneOf<Input> { OneOf(description: "any", contains: { _ in true }) }

		assertParseAll(
			Capture(!"abc" • !" " • any()),
			input: "ab abc abcd ".utf8,
			result: ["a", "b", "b", "c", "b", "c", "d"].map { $0.utf8 })

		assertParseAll(
			Capture(" " • (!OneOf(" ")).repeat(2) • "d"), // repeat a parser of length 0.
			input: " d cd", result: [" d"])

		assertParseMarkers(!any(), input: "  |") // EOF
		assertParseMarkers(try Parser(!any()), input: "|")
	}

	func testAnd() throws {
		assertParseAll(Capture(&&letter • ascii), input: "1abøcæ", result: ["a", "b", "c"])
		assertParseAll(Capture(&&Line.Start() • "a"), input: "abø\ncæa\na".utf8, result: "a".utf8, count: 2)

		/* TODO: uncomment
		 // find last occurence of "xuxu", even if it overlaps with itself.
		 assertParseMarkers(try Parser(Grammar { g in g.last <- &&"xuxu" • any / any • g.last }+ • any.repeat(3)),
		 input: "xuxuxuxu|i")
		 */
	}
}
