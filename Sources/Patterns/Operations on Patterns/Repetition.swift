//
//  Repetition.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public struct RepeatPattern<Repeated: Pattern>: Pattern {
	public let repeatedPattern: Repeated
	public let min: Int
	public let max: Int?

	init<R: RangeExpression>(repeatedPattern: Repeated, range: R) where R.Bound == Int {
		let actualRange = range.relative(to: 0 ..< Int.max)
		self.repeatedPattern = repeatedPattern
		self.min = actualRange.lowerBound
		self.max = actualRange.upperBound == Int.max ? nil : actualRange.upperBound - 1
	}

	public var description: String {
		"\(repeatedPattern){\(min)...\(max.map(String.init) ?? "")}"
	}

	public func createInstructions(_ instructions: inout Instructions) {
		let repeatedInstructions = repeatedPattern.createInstructions()
		for _ in 0 ..< min { instructions.append(contentsOf: repeatedInstructions) }
		if let max = max {
			instructions.append(contentsOf: (min ..< max).flatMap { _ in
				// TODO: move out of loop
				Array<Instruction> {
					$0 += .split(first: 1, second: repeatedInstructions.count + 2)
					$0 += repeatedInstructions
					$0 += .cancelLastSplit
				}
			})
		} else {
			instructions.append {
				$0 += .split(first: 1, second: repeatedInstructions.count + 3)
				$0 += repeatedInstructions
				$0 += .cancelLastSplit
				$0 += .jump(relative: -repeatedInstructions.count - 2)
			}
		}
	}
}

extension Pattern {
	public func `repeat`<R: RangeExpression>(_ range: R) -> RepeatPattern<Self> where R.Bound == Int {
		return RepeatPattern(repeatedPattern: self, range: range)
	}

	public func `repeat`(_ count: Int) -> RepeatPattern<Self> {
		return RepeatPattern(repeatedPattern: self, range: count ... count)
	}
}

postfix operator *

public postfix func * <P: Pattern>(me: P) -> RepeatPattern<P> {
	me.repeat(0...)
}

public postfix func * (me: Literal) -> RepeatPattern<Literal> {
	me.repeat(0...)
}

postfix operator +

public postfix func + <P: Pattern>(me: P) -> RepeatPattern<P> {
	me.repeat(1...)
}

public postfix func + (me: Literal) -> RepeatPattern<Literal> {
	me.repeat(1...)
}

postfix operator ¿

public postfix func ¿ <P: Pattern>(me: P) -> RepeatPattern<P> {
	me.repeat(0 ... 1)
}

public postfix func ¿ (me: Literal) -> RepeatPattern<Literal> {
	me.repeat(0 ... 1)
}
