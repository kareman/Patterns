//
//  PatternTests.swift
//  Patterns
//
//  Created by Kåre Morstøl on 20/03/2017.
//
//

import Patterns
import XCTest

class PatternTests: XCTestCase {
	func testLiteral() {
		assertParseAll(Literal("a"), input: "abcd", result: "a", count: 1)
		assertParseAll(Literal("b"), input: "abcdb", result: "b", count: 2)
		assertParseAll(Literal("ab"), input: "abcaba", result: "ab", count: 2)
	}

	func testOneOf() {
		let vowels = OneOf("aeiouAEIOU")
		assertParseAll(vowels, input: "I am, you are", result: ["I", "a", "o", "u", "a", "e"])

		let lowercaseASCII = OneOf(description: "lowercaseASCII") { character in
			character.isASCII && character.isLowercase
		}
		assertParseAll(lowercaseASCII, input: "aTæøåk☀️", result: ["a", "k"])

		assertParseAll(digit, input: "ab12c3,d4", count: 4)
	}

	func testOptional() throws {
		assertParseAll(letter • digit*, input: "123abc123d", count: 4)
		assertParseAll(digit¿ • letter,
		               input: "123abc", result: ["3a", "b", "c"])
	}

	func testRepeat() throws {
		assertParseAll(digit.repeat(2...), input: "123abc123", count: 2)
		assertParseAll(digit+, input: "123abc", result: "123", count: 1)
		assertParseAll(digit.repeat(3...), input: "123abc", result: "123", count: 1)
		assertParseAll(digit.repeat(4...), input: "123abc", count: 0)

		assertParseAll(digit+, input: "a123abc123d", result: "123", count: 2)
		assertParseAll(digit+, input: "123abc09d4 8", count: 4)
		assertParseAll(digit.repeat(...2) • letter, input: "123abc09d4 8", result: ["23a", "b", "c", "09d"])

		assertParseAll(digit.repeat(1 ... 2), input: "123abc09d48", result: ["12", "3", "09", "48"])

		assertParseAll(digit.repeat(2), input: "1234 5 6 78", result: ["12", "34", "78"])

		assertParseAll("a"* • "b", input: "b aabb ab", result: ["b", "aab", "b", "ab"])
		assertParseAll("a"*, input: "b aabb ab", result: ["", "", "aa", "", "", "", "a", "", ""])

		// !a b == b - a
		assertParseAll(
			(newline.not • ascii)+,
			input: "123\n4567\n89", result: ["123", "4567", "89"])
		assertParseAll(
			(ascii - newline)+,
			input: "123\n4567\n89", result: ["123", "4567", "89"])

		XCTAssertEqual(digit+.description, "digit{1...}")
	}

	func testOrPattern() {
		let pattern = "a" / "b"
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
			Line.start • "line",
			input: text, result: "line", count: 4)
		assertParseAll(
			digit • Skip() • Line.start • "l",
			input: text, result: ["1\nl", "2\nl", "3\nl"])

		/* TODO: Implement?
		 XCTAssertThrowsError(Line.start, Line.start))
		 XCTAssertThrowsError(Line.start, Capture(Line.start)))
		 XCTAssertThrowsError(
		 	[Line.start, Skip(), Line.start]))
		 */
		XCTAssertNoThrow(Line.start • Skip(alphanumeric / "\n") • Line.start)
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
			digit • Line.end,
			input: text, result: ["1", "2", "3", "4"])
		assertParseAll(
			digit • Line.end • Skip() • "l",
			input: text, result: ["1\nl", "2\nl", "3\nl"])

		/* TODO: Implement?
		 XCTAssertThrowsError(Line.end, Line.end))
		 XCTAssertThrowsError(
		 	Line.end, Capture(Line.end)))
		 XCTAssertThrowsError(
		 	Line.end, Skip(), Line.end))
		 */

		XCTAssertNoThrow(
			Line.end • Skip(alphanumeric / "\n") • Line.end)

		assertParseAll(
			Line.end,
			input: "\n", count: 2)
	}

	func testLine() throws {
		let text = """
		line 1

		line 3
		line 4

		"""

		assertParseAll(Line(), input: text, result: ["line 1", "", "line 3", "line 4", ""])
	}

	func testWordBoundary() throws {
		let pattern = Word.boundary
		assertParseMarkers(pattern, input: #"|I| |said| |"|hello|"|"#)
		assertParseMarkers(pattern, input: "|this| |I| |-|3,875.08| |can't|,| |you| |letter|-|like|.| |And|?| |then|")
	}

	func testNotParser() throws {
		assertParseMarkers(alphanumeric.not, input: #"I| said|,| 3|"#)
		assertParseAll(
			Word.boundary • !digit • alphanumeric+,
			input: "123 abc 1ab a32b",
			result: ["abc", "a32b"])

		assertParseAll(
			" " • (!OneOf(" ")).repeat(2) • "d", // test repeating a parser of length 0
			input: " d cd", result: [" d"])
	}
}
