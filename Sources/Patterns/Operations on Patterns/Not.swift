//
//  Negation.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

/// A pattern which only succeeds if the `wrapped` pattern fails.
/// The next pattern will continue from where `wrapped` started.
public struct NotPattern<Wrapped: Pattern>: Pattern {
	public let wrapped: Wrapped
	public var description: String { "!\(wrapped)" }

	@inlinable
	init(_ wrapped: Wrapped) {
		self.wrapped = wrapped
	}

	@inlinable
	public func createInstructions(_ instructions: inout Instructions) throws {
		let wrappedInstructions = try wrapped.createInstructions()
		instructions.append(.choice(offset: wrappedInstructions.count + 3))
		instructions.append(contentsOf: wrappedInstructions)
		instructions.append(.commit)
		instructions.append(.fail)
	}
}

/// Will only succeed if the following pattern fails. Does not consume any input.
@inlinable
public prefix func ! <P: Pattern>(pattern: P) -> NotPattern<P> {
	NotPattern(pattern)
}

/// Will only succeed if the following pattern fails. Does not consume any input.
@inlinable
public prefix func ! (pattern: Literal) -> NotPattern<Literal> {
	NotPattern(pattern)
}
