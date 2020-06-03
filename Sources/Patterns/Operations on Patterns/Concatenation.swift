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

public struct ConcatenationPattern<Left: Pattern, Right: Pattern>: Pattern {
	public let left: Left
	public let right: Right
	public var description: String { "\(left) \(right)" }

	init(left: Left, right: Right) {
		self.left = left
		self.right = right
	}
}

extension ConcatenationPattern where Left == Skip<AnyPattern> {
	// Is never called. Don't know why.
	public func createInstructions(_ instructions: inout Instructions) {
		let rightInstructions = right.createInstructions()
		instructions.append(contentsOf: left.prependSkip(rightInstructions))
	}
}

extension ConcatenationPattern {
	public func createInstructions(_ instructions: inout Instructions) {
		if let skip = left as? Skip<AnyPattern> {
			let rightInstructions = right.createInstructions()
			instructions.append(contentsOf: skip.prependSkip(rightInstructions))
		} else {
			left.createInstructions(&instructions)
			right.createInstructions(&instructions)
		}
	}
}

public func • <Left, Right>(lhs: Left, rhs: Right) -> ConcatenationPattern<Left, Right> {
	ConcatenationPattern(left: lhs, right: rhs)
}

public func • <Right>(lhs: Literal, rhs: Right) -> ConcatenationPattern<Literal, Right> {
	ConcatenationPattern(left: lhs, right: rhs)
}

public func • <Left>(lhs: Left, rhs: Literal) -> ConcatenationPattern<Left, Literal> {
	ConcatenationPattern(left: lhs, right: rhs)
}

public func • (lhs: Literal, rhs: Literal) -> ConcatenationPattern<Literal, Literal> {
	ConcatenationPattern(left: lhs, right: rhs)
}
