
import Patterns
import XCTest

class LongTests: XCTestCase {
	func testOr() {
		let char = letter / ascii / punctuation
		XCTAssert(type(of: "a" / char / "b")
			== OrPattern<OrPattern<Literal<String>, OneOf<String>>, Literal<String>>.self,
		          "'/' operator isn't optimizing OneOf's properly.")
	}

	func testNot() {
		XCTAssert(
			type(of: "a" • !letter • ascii • "b") == Concat<Concat<Literal<String>, OneOf<String>>, Literal<String>>.self,
			"'•' operator isn't optimizing OneOf's properly.")
	}

	func testAnd() throws {
		XCTAssert(
			type(of: "a" • &&letter • ascii • "b") == Concat<Concat<Literal<String>, OneOf<String>>, Literal<String>>.self,
			"'•' operator isn't optimizing OneOf's properly.")
	}

	func testOperatorPrecedence() throws {
		let p1 = "a" • Skip() • letter • !alphanumeric • "b"+
		XCTAssert(type(of: p1.first.first.first.second) == Skip<String>.self)
		XCTAssert(type(of: Literal<String.UTF8View>("a") • "b" / "c" • "d")
			== OrPattern<Concat<Literal<String.UTF8View>, Literal<String.UTF8View>>, Concat<Literal<String.UTF8View>, Literal<String.UTF8View>>>.self,
		          #"`/` should have lower precedence than `•`"#)
	}

	func testPlaygroundExample() throws {
		let text = #"""
		0   0.0   0.01
		-0   +0   -0.0   +0.0
		-123.456e+00   -123.456E+00   -123.456e-00   -123.456E-00
		+123.456e+00   +123.456E+00   +123.456e-00   +123.456E-00
		0   0.0   0.01
		-123e+12   -123e-12
		123.456e+00   123.456E+00
		0x123E   0x123e
		0x0123456789abcdef
		0b0   0b1   0b0000   0b0001   0b11110000   0b0000_1111   0b1010_00_11
		"""#

		let unsigned = digit+
		let sign = "-" / "+"
		let integer = Capture(name: "integer", sign¿ • unsigned)
		let hexa = Capture(name: "hexa", "0x" • hexDigit+)
		let binary = Capture(name: "binary", "0b" • OneOf("01") • OneOf("01_")*)
		let floating = Capture(name: "floating", integer • "." • unsigned)
		let scientific = floating • (("e" / "E") • integer)¿
		let number = hexa / binary / floating / integer / unsigned / scientific

		let parser = try Parser(search: number)

		XCTAssertEqual(Array(parser.matches(in: text)).count, 44)
	}

	// from http://www.inf.puc-rio.br/~roberto/docs/peg.pdf, page 2 and 5
	static let pegGrammar = Grammar<String> { g in
		//g.all     <- g.pattern • !any
		g.pattern <- g.grammar / g.simplepatt
		g.grammar <- (g.nonterminal • "<-" • g.sp • g.simplepatt)+
		g.simplepatt <- g.alternative • ("/" • g.sp • g.alternative)*
		g.alternative <- (OneOf("!&")¿ • g.sp • g.suffix)+
		g.suffix <- g.primary • (OneOf("*+?") • g.sp)*
		let primaryPart1 = "(" • g.sp • g.pattern • ")" • g.sp / "." • g.sp / g.literal
		g.primary <- primaryPart1 / g.charclass / g.nonterminal • !"<-"
		g.literal <- "’" • (!"’" • any)* • "’" • g.sp
		g.charclass <- "[" • (!"]" • (any • "-" • any / any))* • "]" • g.sp
		g.nonterminal <- OneOf("a" ... "z", "A" ... "Z")+ • g.sp
		g.sp <- OneOf(" \t\n")*
	}

	static let pegGrammarParser = { try! Parser(pegGrammar) }()

	func testPEGGrammar() throws {
		// page 5
		let grammar1Text = """
		pattern      <- grammar / simplepatt
		grammar      <- (nonterminal ’<-’ sp simplepatt)+
		simplepatt   <- alternative (’/’ sp alternative)*
		alternative  <- ([!&]? sp suffix)+
		suffix       <- primary ([*+?] sp)*
		primary      <- ’(’ sp pattern ’)’ sp / ’.’ sp / literal / charclass / nonterminal !’<-’
		literal      <- [’] (![’] .)* [’] sp
		charclass    <- ’[’ (!’]’ (. ’-’ . / . ))* ’]’ sp
		nonterminal  <- [a-zA-Z]+ sp
		sp           <- [ \t\n]*
		"""
		XCTAssertEqual(Self.pegGrammarParser.match(in: grammar1Text)?.endIndex, grammar1Text.endIndex)

		// page 2
		let grammar2Text = """
		grammar      <- (nonterminal ’<-’ sp pattern)+
		pattern      <- alternative (’/’ sp alternative)*
		alternative  <- ([!&]? sp suffix)+
		suffix       <- primary ([*+?] sp)*
		primary      <- ’(’ sp pattern ’)’ sp / ’.’ sp / literal / charclass / nonterminal !’<-’
		literal      <- [’] (![’] .)* [’] sp
		charclass    <- ’[’ (!’]’ (. ’-’ . / . ))* ’]’ sp
		nonterminal  <- [a-zA-Z]+ sp
		sp           <- [ \t\n]*
		"""
		XCTAssertEqual(Self.pegGrammarParser.match(in: grammar2Text)?.endIndex, grammar2Text.endIndex)
	}

	func testOriginalPEGGrammar() throws {
		try XCTSkipIf(true, "pegGrammar does not support escaping characters.")

		// https://bford.info/pub/lang/peg.pdf Page 2, Figure 1.
		let origPEGGrammarText = """
		# Hierarchical syntax
		Grammar <- Spacing Definition+ EndOfFile
		Definition <- Identifier LEFTARROW Expression
		Expression <- Sequence (SLASH Sequence)*
		Sequence <- Prefix*
		Prefix <- (AND / NOT)? Suffix
		Suffix <- Primary (QUESTION / STAR / PLUS)?
		Primary <- Identifier !LEFTARROW / OPEN Expression CLOSE / Literal / Class / DOT

		# Lexical syntax
		Identifier <- IdentStart IdentCont* Spacing
		IdentStart <- [a-zA-Z_]
		IdentCont <- IdentStart / [0-9]
		Literal <- [’] (![’] Char)* [’] Spacing / ["] (!["] Char)* ["] Spacing
		Class <- ’[’ (!’]’ Range)* ’]’ Spacing
		Range <- Char ’-’ Char / Char
		Char <- ’\\’ [nrt’"[]\\] / ’\\’ [0-2][0-7][0-7] / ’\\’ [0-7][0-7]? / !’\\’ .
		LEFTARROW <- ’<-’ Spacing
		SLASH <- ’/’ Spacing
		AND <- ’&’ Spacing
		NOT <- ’!’ Spacing
		QUESTION <- ’?’ Spacing
		STAR <- ’*’ Spacing
		PLUS <- ’+’ Spacing
		OPEN <- ’(’ Spacing
		CLOSE <- ’)’ Spacing
		DOT <- ’.’ Spacing
		Spacing <- (Space / Comment)*
		Comment <- ’#’ (!EndOfLine .)* EndOfLine
		Space <- ’ ’ / ’\t’ / EndOfLine
		EndOfLine <- ’\r\n’ / ’\n’ / ’\r’
		EndOfFile <- !.
		"""
		XCTAssertEqual(Self.pegGrammarParser.match(in: origPEGGrammarText)?.endIndex, origPEGGrammarText.endIndex)
	}
}
