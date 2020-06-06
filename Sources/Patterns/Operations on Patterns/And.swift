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

	public func createInstructions(_ instructions: inout Instructions) {
		let wrappedInstructions = wrapped.createInstructions()
		if let indexMovedBy = wrappedInstructions.movesIndexBy {
			instructions.append {
				$0 += wrappedInstructions
				$0 += .moveIndex(offset: -indexMovedBy)
			}
		} else {
			instructions.append {
				$0 += .split(first: 1, second: wrappedInstructions.count + 4, atIndex: 0)
				$0 += .split(first: 1, second: wrappedInstructions.count + 1, atIndex: 0)
				$0 += wrappedInstructions
				$0 += .cancelLastSplit
				$0 += .fail
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
