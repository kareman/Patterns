//
//  SkipTests.swift
//
//
//  Created by Kåre Morstøl on 26/06/2020.
//

import Patterns
import XCTest

class SkipTests: XCTestCase {
	func testSimple() throws {
		let text = "This is a test text."
		assertParseAll(
			Capture(" " • Skip() • " "),
			input: text, result: [" is ", " test "])

		assertParseAll(
			Capture(" " • Skip() • "d"),
			input: " ad d", result: [" ad", " d"])
	}

	func testWithCapture() throws {
		let text = "This is a test text."
		assertParseAll(
			" " • Capture(letter • Skip()) • " ",
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			" " • Capture(Skip() • letter+) • " ",
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			" " • Capture(Skip()) • " ",
			input: text, result: ["is", "a", "test"])

		let lines = """
		1
		2

		3
		"""
		assertParseAll(Line.start • Capture(Skip()) • Line.end,
		               input: lines, result: ["1", "2", "", "3"])
		assertParseAll(Capture(Line.start • Skip() • Line.end),
		               input: lines, result: ["1", "2", "", "3"])

		// undefined (Skip at end)
		_ = try Parser(search: " " • Capture(Skip()))
			.matches(in: text)
	}

	func testInsideOptional() throws {
		assertParseMarkers((Skip() • " ")¿, input: "This |is |a |test |t|e|x|t|.|")
		assertParseMarkers((Skip() • " ")+, input: "This is a test |text.")
		assertParseMarkers(Skip() • " ", input: "This |is |a |test |text.")

		assertParseMarkers((" " • Skip())¿ • letter, input: "T|h|i|s| i|s|")
		assertParseMarkers((" " • Skip())+ • letter, input: "This i|s a| t|est t|ext.")
		assertParseMarkers(" " • Skip() • letter, input: "This i|s a| t|est t|ext.")
	}

	func testInsideChoice() {
		assertParseMarkers((Skip() • " ") / letter, input: "This |is |a |test |t|e|x|t|.")
		assertParseMarkers((" " • Skip()) / letter, input: "T|h|i|s| |i|s|")
		assertParseMarkers(letter / (" " • Skip()), input: "T|h|i|s| |i|s|")
		assertParseMarkers(letter / (Skip() • " "), input: "T|h|i|s|, |i|s| |")
	}

	func testDoubleSkip() throws {
		assertParseMarkers(try Parser(Skip() • Skip() • " "), input: "This |is")
	}
}
