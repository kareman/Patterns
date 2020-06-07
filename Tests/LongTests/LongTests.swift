
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
			type(of: "a" • !letter • ascii • "b") == Concat<Literal, Concat<OneOf, Literal>>.self,
			"'•' operator isn't optimizing OneOf's properly.")
	}

	func testAnd() throws {
		XCTAssert(
			type(of: "a" • &&letter • ascii • "b") == Concat<Literal, Concat<OneOf, Literal>>.self,
			"'•' operator isn't optimizing OneOf's properly.")
	}
}
