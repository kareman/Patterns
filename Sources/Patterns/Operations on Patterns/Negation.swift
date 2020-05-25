//
//  Negation.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public struct NotPattern<Wrapped: TextPattern>: TextPattern {
	public let pattern: Wrapped
	public var description: String { "!\(pattern)" }

	public func createInstructions() -> [Instruction<Input>] {
		let instructions = pattern.createInstructions()
		return Array<Instruction> {
			$0 += .split(first: 1, second: instructions.count + 3)
			$0 += instructions
			$0 += .cancelLastSplit
			$0 += .checkIndex { _, _ in false }
		}
	}
}

extension TextPattern {
	public var not: NotPattern<Self> { NotPattern(pattern: self) }

	public static prefix func ! (me: Self) -> NotPattern<Self> {
		me.not
	}
}

public prefix func ! (me: Literal) -> NotPattern<Literal> {
	me.not
}
