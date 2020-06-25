//
//  SwiftPattern.swift
//  Patterns
//
//  Created by Kåre Morstøl on 20/03/2017.
//
//

import Foundation

/// A pattern which first tries the `first` pattern,
/// if that fails it tries the `second` pattern from the same position.
public struct OrPattern<First: Pattern, Second: Pattern>: Pattern {
	public let first: First
	public let second: Second

	@inlinable
	init(_ first: First, or second: Second) {
		self.first = first
		self.second = second
	}

	public var description: String {
		"(\(first) / \(second))"
	}

	@inlinable
	public func createInstructions(_ instructions: inout Instructions) throws {
		let inst1 = try first.createInstructions()
		let inst2 = try second.createInstructions()
		instructions.append(.choice(offset: inst1.count + 3))
		instructions.append(contentsOf: inst1)
		instructions.append(.commit)
		instructions.append(.jump(offset: inst2.count + 2))
		instructions.append(contentsOf: inst2)
		instructions.append(.choiceEnd)
	}
}

/// First tries the pattern to the left,
/// if that fails it tries the pattern to the right from the same position.
@inlinable
public func / <First: Pattern, Second: Pattern>(p1: First, p2: Second) -> OrPattern<First, Second> {
	OrPattern(p1, or: p2)
}

/// First tries the pattern to the left,
/// if that fails it tries the pattern to the right from the same position.
@inlinable
public func / <Second: Pattern>(p1: Literal, p2: Second) -> OrPattern<Literal, Second> {
	OrPattern(p1, or: p2)
}

/// First tries the pattern to the left,
/// if that fails it tries the pattern to the right from the same position.
@inlinable
public func / <First: Pattern>(p1: First, p2: Literal) -> OrPattern<First, Literal> {
	OrPattern(p1, or: p2)
}

/// First tries the pattern to the left,
/// if that fails it tries the pattern to the right from the same position.
@inlinable
public func / (p1: Literal, p2: Literal) -> OrPattern<Literal, Literal> {
	OrPattern(p1, or: p2)
}
