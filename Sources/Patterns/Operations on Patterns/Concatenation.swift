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

/// A pattern which first tries the `first` pattern,
/// if that succeeds it continues with the `second` pattern.
public struct Concat<First: Pattern, Second: Pattern>: Pattern where First.Input == Second.Input {
	public typealias Input = First.Input
	public let first: First
	public let second: Second
	public var description: String { "\(first) \(second)" }

	@inlinable
	init(_ first: First, _ second: Second) {
		self.first = first
		self.second = second
	}

	@inlinable
	public func createInstructions(_ instructions: inout ContiguousArray<Instruction<Input>>) throws {
		try first.createInstructions(&instructions)
		try second.createInstructions(&instructions)
	}
}

/// First tries the pattern to the left, if that succeeds it tries the pattern to the right.
@inlinable
public func • <Left, Right>(lhs: Left, rhs: Right) -> Concat<Left, Right> where Left.Input == Right.Input {
	Concat(lhs, rhs)
}

/// First tries the pattern to the left, if that succeeds it tries the pattern to the right.
@inlinable
public func • <Right: Pattern>(lhs: Literal<Right.Input>, rhs: Right) -> Concat<Literal<Right.Input>, Right> {
	Concat(lhs, rhs)
}

/// First tries the pattern to the left, if that succeeds it tries the pattern to the right.
@inlinable
public func • <Left: Pattern>(lhs: Left, rhs: Literal<Left.Input>) -> Concat<Left, Literal<Left.Input>> {
	Concat(lhs, rhs)
}

/// First tries the pattern to the left, if that succeeds it tries the pattern to the right.
@inlinable
public func • <Input>(lhs: Literal<Input>, rhs: Literal<Input>) -> Concat<Literal<Input>, Literal<Input>> {
	Concat(lhs, rhs)
}
