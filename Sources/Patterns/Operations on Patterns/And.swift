//
//  And.swift
//
//
//  Created by Kåre Morstøl on 04/06/2020.
//

public struct AndPattern<Wrapped: Pattern>: Pattern {
	public let wrapped: Wrapped
	public var description: String { "&\(wrapped)" }

	init(_ wrapped: Wrapped) {
		self.wrapped = wrapped
	}

	public func createInstructions(_ instructions: inout Instructions) throws {
		let wrappedInstructions = try wrapped.createInstructions()
		if let indexMovedBy = wrappedInstructions.movesIndexBy {
			instructions.append(contentsOf: wrappedInstructions)
			instructions.append(.moveIndex(offset: -indexMovedBy))
		} else {
			instructions.append { // TODO: test
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
	public static prefix func && (me: Self) -> AndPattern<Self> {
		AndPattern(me)
	}
}

extension Literal {
	public static prefix func && (me: Literal) -> AndPattern<Literal> {
		AndPattern(me)
	}
}
