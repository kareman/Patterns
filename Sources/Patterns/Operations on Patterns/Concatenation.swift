//
//  Concatenation.swift
//
//
//  Created by Kåre Morstøl on 21/05/2020.
//

precedencegroup PatternConcatenationPrecedence {
	associativity: left
	higherThan: MultiplicationPrecedence // `/` has this
}

infix operator •: PatternConcatenationPrecedence

public struct Concat<First: Pattern, Second: Pattern>: Pattern {
	public let first: First
	public let second: Second
	public var description: String { "\(first) \(second)" }

	init(_ first: First, _ second: Second) {
		self.first = first
		self.second = second
	}
}

extension Concat {
	public func createInstructions(_ instructions: inout Instructions) throws {
		try first.createInstructions(&instructions)
		try second.createInstructions(&instructions)
	}
}

public func • <Left, Right>(lhs: Left, rhs: Right) -> Concat<Left, Right> {
	Concat(lhs, rhs)
}

public func • <Right>(lhs: Literal, rhs: Right) -> Concat<Literal, Right> {
	Concat(lhs, rhs)
}

public func • <Left>(lhs: Left, rhs: Literal) -> Concat<Left, Literal> {
	Concat(lhs, rhs)
}

public func • (lhs: Literal, rhs: Literal) -> Concat<Literal, Literal> {
	Concat(lhs, rhs)
}
