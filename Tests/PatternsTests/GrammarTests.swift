//
//  GrammarTests.swift
//
//
//  Created by Kåre Morstøl on 27/05/2020.
//

import Patterns
import XCTest

class GrammarTests: XCTestCase {
	let grammar1: Grammar = {
		let g = Grammar()
		g.letter <- Capture(letter)
		g.space <- whitespace
		return g
	}()

	func testNamesAnonymousCaptures() {
		XCTAssertEqual((grammar1.patterns["letter"]?.wrapped as? Capture<OneOf>)?.name, "letter")
	}

	func testSetsFirstPattern() {
		XCTAssertEqual(grammar1.firstPattern, "letter")
	}

	func testDirectRecursion() throws {
		let g = Grammar()
		g.balancedParentheses <- "(" • (!OneOf("()") • any / g.balancedParentheses)* • ")"
		assertParseAll(g, input: "((( )( )))", count: 1)
		assertParseAll(g, input: "( )", count: 1)
		assertParseAll(g, input: "(( )", count: 0)

	}
}
