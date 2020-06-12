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

	func testArithmetic() throws {
		let g = Grammar { g in
			g.all <- g.expr • !any
			g.expr <- g.sum
			g.sum <- g.product • (("+" / "-") • g.product)*
			g.product <- g.power • (("*" / "/") • g.power)*
			g.power <- g.value • ("^" • g.power)¿
			g.value <- digit+ / "(" • g.expr • ")"
		}

		let p = try Parser(g)
		assertParseMarkers(p, input: "1+2-3*(4+3)|")
		assertParseAll(p, input: "1+2(", count: 0)
	}
}
