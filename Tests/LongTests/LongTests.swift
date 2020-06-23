
import Patterns
import XCTest

class LongTests: XCTestCase {
	func testOr() {
		XCTAssert(type(of: "a" / letter / ascii / punctuation / "b")
			== OrPattern<OrPattern<Literal, OneOf>, Literal>.self,
		          "'/' operator isn't optimizing OneOf's properly.")
	}

	func testNot() {
		XCTAssert(
			type(of: "a" • !letter • ascii • "b") == Concat<Concat<Literal, OneOf>, Literal>.self,
			"'•' operator isn't optimizing OneOf's properly.")
	}

	func testAnd() throws {
		XCTAssert(
			type(of: "a" • &&letter • ascii • "b") == Concat<Concat<Literal, OneOf>, Literal>.self,
			"'•' operator isn't optimizing OneOf's properly.")
	}

	func testPlaygroundExample() throws {
		let text = """
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
		"""

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
}
