//
//  Concatenation.swift
//
//
//  Created by Kåre Morstøl on 21/05/2020.
//

precedencegroup PatternConcatenationPrecedence {
	associativity: right // so allmost all `Skip` will be to the left and we can see what comes after.
	higherThan: MultiplicationPrecedence // `/` has this
}

infix operator •: PatternConcatenationPrecedence

public struct Concat<Left: Pattern, Right: Pattern>: Pattern {
	public let left: Left
	public let right: Right
	public var description: String { "\(left) \(right)" }

	init(left: Left, right: Right) {
		self.left = left
		self.right = right
	}
}

extension Concat where Left == Skip<AnyPattern> {
	// Is never called. Don't know why.
	public func createInstructions(_ instructions: inout Instructions) throws {
		let rightInstructions = try right.createInstructions()
		instructions.append(contentsOf: try left.prependSkip(rightInstructions))
	}
}

extension Concat {
	public func createInstructions(_ instructions: inout Instructions) throws {
		if let skip = left as? Skip<AnyPattern> {
			let rightInstructions = try right.createInstructions()
			instructions.append(contentsOf: try skip.prependSkip(rightInstructions))
		} else {
			try left.createInstructions(&instructions)
			try right.createInstructions(&instructions)
		}
	}
}

public func • <Left, Right>(lhs: Left, rhs: Right) -> Concat<Left, Right> {
	Concat(left: lhs, right: rhs)
}

public func • <Right>(lhs: Literal, rhs: Right) -> Concat<Literal, Right> {
	Concat(left: lhs, right: rhs)
}

public func • <Left>(lhs: Left, rhs: Literal) -> Concat<Left, Literal> {
	Concat(left: lhs, right: rhs)
}

public func • (lhs: Literal, rhs: Literal) -> Concat<Literal, Literal> {
	Concat(left: lhs, right: rhs)
}
