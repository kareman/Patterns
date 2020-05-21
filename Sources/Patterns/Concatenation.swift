//
//  Concatenation.swift
//
//
//  Created by Kåre Morstøl on 21/05/2020.
//

infix operator •: AdditionPrecedence

public struct ConcatenationPattern: TextPattern {
	public var description: String { "\(first) \(second)" }

	let first, second: TextPattern

	public func createInstructions() -> [Instruction] {
		first.createInstructions() + second.createInstructions()
	}
}

public func • (lhs: TextPattern, rhs: TextPattern) -> ConcatenationPattern {
	ConcatenationPattern(first: lhs, second: rhs)
}

public func • (lhs: Literal, rhs: TextPattern) -> ConcatenationPattern {
	ConcatenationPattern(first: lhs, second: rhs)
}

public func • (lhs: TextPattern, rhs: Literal) -> ConcatenationPattern {
	ConcatenationPattern(first: lhs, second: rhs)
}
