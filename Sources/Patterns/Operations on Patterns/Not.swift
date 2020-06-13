//
//  Negation.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public struct NotPattern<Wrapped: Pattern>: Pattern {
	public let wrapped: Wrapped
	public var description: String { "!\(wrapped)" }

	public func createInstructions(_ instructions: inout Instructions) throws {
		let wrappedInstructions = try wrapped.createInstructions()
		instructions.append(.split(first: 1, second: wrappedInstructions.count + 3))
		instructions.append(contentsOf: wrappedInstructions)
		instructions.append(.cancelLastSplit)
		instructions.append(.fail)
	}
}

extension Pattern {
	public var not: NotPattern<Self> { NotPattern(wrapped: self) }

	public static prefix func ! (me: Self) -> NotPattern<Self> {
		me.not
	}
}

public prefix func ! (me: Literal) -> NotPattern<Literal> {
	me.not
}
