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
		let p = " " • Capture(Skip()) • " "
		assertParseAll(
			p,
			input: text, result: ["is", "a", "test"])
		assertParseAll(
			" " • Capture(Skip()) • " ",
			input: text.utf8, result: ["is", "a", "test"].map { $0.utf8 })

		let lines = """
		1
		2

		3
		"""
		assertParseAll(Line.start • Capture(Skip()) • Line.end,
		               input: lines, result: ["1", "2", "", "3"])
		assertParseAll(Capture(Line.start • Skip() • Line.end),
		               input: lines, result: ["1", "2", "", "3"])
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

	func testAtTheEnd() throws {
		assertParseMarkers(" " • Skip(), input: "a |bee")
		assertParseAll(" " • Capture(Skip()), input: "a bee", result: [""])

		// used in documentation for Skip.

		let s = Skip()
		assertParseMarkers(try Parser(s • " "), input: "jfd | |jlj |")

		let g = Grammar { g in
			g.nextSpace <- g.skip • " "
			g.skip <- Skip() // Does not work.
		}
		assertParseMarkers(try Parser(g), input: "sdf ksj")
	}

	func testBeforeGrammarTailCall() throws {
		let recursive = Grammar { g in
			g.a <- " " • Skip() • g.a
		}
		assertParseAll(recursive, input: "This is a test text.", count: 0)

		let callAnother = Grammar { g in
			g.a <- " " • Skip() • g.b
			g.b <- letter
		}
		assertParseMarkers(callAnother, input: "This i|s a| t|est t|ext.")
		assertParseMarkers(" " • Skip() • letter, input: "This i|s a| t|est t|ext.")
	}

	func testBeforeGrammarCallInChoice() {
		let g = Grammar { g in
			g.a <- " " • (Skip() • g.a / letter)
		}
		assertParseMarkers(g, input: "This is a test t|ext.")
	}
}
