//
//  SwiftPattern.swift
//  Patterns
//
//  Created by Kåre Morstøl on 20/03/2017.
//
//

import Foundation

public struct OrPattern<First: Pattern, Second: Pattern>: Pattern {
	public let first: First
	public let second: Second

	init(_ first: First, or second: Second) {
		self.first = first
		self.second = second
	}

	public var description: String {
		return "(\(first) / \(second))"
	}

	public func createInstructions() -> [Instruction<Input>] {
		let (inst1, inst2) = (first.createInstructions(), second.createInstructions())
		return Array<Instruction> {
			$0 += .split(first: 1, second: inst1.count + 3)
			$0 += inst1
			$0 += .cancelLastSplit
			$0 += .jump(relative: inst2.count + 1)
			$0 += inst2
		}
	}
}

public func / <First: Pattern, Second: Pattern>(p1: First, p2: Second) -> OrPattern<First, Second> {
	return OrPattern(p1, or: p2)
}

public func / <Second: Pattern>(p1: Literal, p2: Second) -> OrPattern<Literal, Second> {
	return OrPattern(p1, or: p2)
}

public func / <First: Pattern>(p1: First, p2: Literal) -> OrPattern<First, Literal> {
	return OrPattern(p1, or: p2)
}

public func / (p1: Literal, p2: Literal) -> OrPattern<Literal, Literal> {
	return OrPattern(p1, or: p2)
}
