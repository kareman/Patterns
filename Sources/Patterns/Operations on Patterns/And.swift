//
//  And.swift
//
//
//  Created by Kåre Morstøl on 04/06/2020.
//

/// A pattern which matches the `wrapped` pattern, without consuming any input.
public struct AndPattern<Wrapped: Pattern>: Pattern {
	public typealias Input = Wrapped.Input
	public let wrapped: Wrapped
	public var description: String { "&\(wrapped)" }

	@usableFromInline
	init(_ wrapped: Wrapped) {
		self.wrapped = wrapped
	}

	@inlinable
	public func createInstructions(_ instructions: inout Instructions) throws {
		let wrappedInstructions = try wrapped.createInstructions()
		if let indexMovedBy = wrappedInstructions.movesIndexBy {
			instructions.append(contentsOf: wrappedInstructions)
			instructions.append(.moveIndex(offset: -indexMovedBy))
		} else {
			instructions.append { // TODO: test. And keep any captures.
				$0.append(.choice(offset: wrappedInstructions.count + 4))
				$0.append(.choice(offset: wrappedInstructions.count + 1))
				$0.append(contentsOf: wrappedInstructions)
				$0.append(.commit)
				$0.append(.fail)
			}
		}
	}
}

prefix operator &&

extension Pattern {
	/// Matches the following pattern without consuming any input.
	@inlinable
	public static prefix func && (me: Self) -> AndPattern<Self> {
		AndPattern(me)
	}
}

extension Literal {
	/// Matches the following pattern without consuming any input.
	@inlinable
	public static prefix func && (me: Literal) -> AndPattern<Literal> {
		AndPattern(me)
	}
}
