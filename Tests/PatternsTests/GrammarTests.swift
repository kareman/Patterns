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

	func testDirectRecursion1() throws {
		let g = Grammar()
		g.a <- "a" / any • g.a
		let g1Parser = try Parser(g)
		assertParseAll(g1Parser, input: " aba", count: 2)
	}

	func testDirectRecursion2() throws {
		let g = Grammar()
		g.balancedParentheses <- "(" • (!OneOf("()") • any / g.balancedParentheses)* • ")"
		let g2Parser = try Parser(g)
		assertParseAll(g2Parser, input: "( )", count: 1)
		assertParseAll(g2Parser, input: "((( )( )))", count: 1)
		assertParseAll(g2Parser, input: "(( )", count: 0)
	}
}
