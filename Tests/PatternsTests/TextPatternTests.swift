//
//  TextPatternTests.swift
//  Patterns
//
//  Created by Kåre Morstøl on 20/03/2017.
//
//

import Foundation
import Patterns
import XCTest

class TextPatternTests: XCTestCase {
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
		assertParseAll(try Patterns(verify: letter, digit.repeat(0...)), input: "123abc123d", count: 4)
		assertParseAll(try Patterns(verify: digit.repeat(0 ... 1), letter),
		               input: "123abc", result: ["3a", "b", "c"])
	}

	func testRepeat() throws {
		assertParseAll(digit.repeat(2...), input: "123abc123", count: 2)
		assertParseAll(digit.repeat(1...), input: "123abc", result: "123", count: 1)
		assertParseAll(digit.repeat(3...), input: "123abc", result: "123", count: 1)
		assertParseAll(digit.repeat(4...), input: "123abc", count: 0)

		assertParseAll(digit.repeat(1...), input: "a123abc123d", result: "123", count: 2)
		assertParseAll(digit.repeat(1...), input: "123abc09d4 8", count: 4)
		assertParseAll(Patterns(digit.repeat(...2), letter), input: "123abc09d4 8", result: ["23a", "b", "c", "09d"])

		assertParseAll(try Patterns(verify: digit.repeat(1 ... 2)), input: "123abc09d48", result: ["12", "3", "09", "48"])

		assertParseAll(digit.repeat(2), input: "1234 5 6 78", result: ["12", "34", "78"])

		XCTAssertEqual(digit.repeat(1...).description, "digit{1...}")
	}

	func testOrPattern() {
		let pattern: TextPattern = Literal("a") || Literal("b")
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
		let hexNumber = Capture(hexDigit.repeat(1...))
		let hexRange = try Patterns(verify: hexNumber, Literal(".."), hexNumber) || hexNumber
		let rangeAndProperty = try Patterns(verify: line.start, hexRange, Skip(), Literal("; "), Capture(Skip()), Literal(" "))

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
		let pattern: TextPattern = line.start
		assertParseAll(pattern, input: "", result: "", count: 1)
		assertParseAll(pattern, input: "\n", count: 2)
		assertParseAll(pattern, input: text, result: "", count: 4)
		assertParseAll(
			try Patterns(verify: line.start, Capture(Skip()), Literal(" ")),
			input: text, result: "line", count: 4)
		assertParseAll(
			try Patterns(verify: line.start, Literal("line")),
			input: text, result: "line", count: 4)
		assertParseAll(
			try Patterns(
				verify: digit, Skip(), line.start, Literal("l")),
			input: text, result: ["1\nl", "2\nl", "3\nl"])

		XCTAssertThrowsError(try Patterns(verify: line.start, line.start))
		XCTAssertThrowsError(try Patterns(verify: line.start, Capture(line.start)))
		XCTAssertThrowsError(
			try Patterns(verify: [line.start, Skip(), line.start]))
		XCTAssertNoThrow(try Patterns(verify: [line.start, Skip(whileRepeating: alphanumeric || Literal("\n")), line.start]))
	}

	func testLineEnd() throws {
		let pattern: TextPattern = line.end
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
			try Patterns(verify: Literal(" "), Capture(Skip()), line.end),
			input: text, result: ["1", "2", "3", "4"])
		assertParseAll(
			try Patterns(verify: digit, line.end),
			input: text, result: ["1", "2", "3", "4"])
		assertParseAll(
			try Patterns(verify: digit, line.end, Skip(), Literal("l")),
			input: text, result: ["1\nl", "2\nl", "3\nl"])

		XCTAssertThrowsError(try Patterns(verify: line.end, line.end))
		XCTAssertThrowsError(
			try Patterns(verify: line.end, Capture(line.end)))
		XCTAssertThrowsError(
			try Patterns(verify: line.end, Skip(), line.end))
		XCTAssertNoThrow(try Patterns(verify: [line.end, Skip(whileRepeating: alphanumeric || Literal("\n")), line.end]))

		assertParseAll(
			try Patterns(verify: line.end),
			input: "\n", count: 2)
	}

	func testLine() throws {
		let text = """
		line 1

		line 3
		line 4

		"""

		assertParseAll(line, input: text, result: ["line 1", "", "line 3", "line 4", ""])
	}

	func testWordBoundary() throws {
		let pattern = try Patterns(verify: Word.boundary)
		assertParseMarkers(pattern, input: #"|I| |said| |"|hello|"|"#)
		assertParseMarkers(pattern, input: "|this| |I| |-|3,875.08| |can't|,| |you| |letter|-|like|.| |And|?| |then|")
	}
}
