//
//  Repetition.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public struct RepeatPattern<Repeated: TextPattern>: TextPattern, RegexConvertible {
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

	public var regex: String {
		"(?:\((repeatedPattern as! RegexConvertible).regex){\(min),\(max.map(String.init(describing:)) ?? "")}"
	}

	public func createInstructions() -> [Instruction<Input>] {
		let repeatedInstructions = repeatedPattern.createInstructions()
		var result = (0 ..< min).flatMap { _ in repeatedInstructions }
		if let max = max {
			result.append(contentsOf: (min ..< max).flatMap { _ in
				Array<Instruction> {
					$0 += .split(first: 1, second: repeatedInstructions.count + 2)
					$0 += repeatedInstructions
					$0 += .cancelLastSplit
				}
			})
		} else {
			result.append {
				$0 += .split(first: 1, second: repeatedInstructions.count + 3)
				$0 += repeatedInstructions
				$0 += .cancelLastSplit
				$0 += .jump(relative: -repeatedInstructions.count - 2)
			}
		}
		return result
	}
}

extension TextPattern {
	public func `repeat`<R: RangeExpression>(_ range: R) -> RepeatPattern<Self> where R.Bound == Int {
		return RepeatPattern(repeatedPattern: self, range: range)
	}

	public func `repeat`(_ count: Int) -> RepeatPattern<Self> {
		return RepeatPattern(repeatedPattern: self, range: count ... count)
	}
}

postfix operator *

public postfix func * <P: TextPattern>(me: P) -> RepeatPattern<P> {
	me.repeat(0...)
}

public postfix func * (me: Literal) -> RepeatPattern<Literal> {
	me.repeat(0...)
}

postfix operator +

public postfix func + <P: TextPattern>(me: P) -> RepeatPattern<P> {
	me.repeat(1...)
}

public postfix func + (me: Literal) -> RepeatPattern<Literal> {
	me.repeat(1...)
}

postfix operator ¿

public postfix func ¿ <P: TextPattern>(me: P) -> RepeatPattern<P> {
	me.repeat(0 ... 1)
}

public postfix func ¿ (me: Literal) -> RepeatPattern<Literal> {
	me.repeat(0 ... 1)
}

extension TextPattern {
	public func callAsFunction<R: RangeExpression>(range: () -> R) -> RepeatPattern<Self>
		where R.Bound == Int {
		self.repeat(range())
	}

	public func callAsFunction(count: () -> Int) -> RepeatPattern<Self> {
		self.repeat(count())
	}
}

extension Literal {
	public func callAsFunction<R: RangeExpression>(range: () -> R) -> RepeatPattern<Literal>
		where R.Bound == Int {
		self.repeat(range())
	}

	public func callAsFunction(count: () -> Int) -> RepeatPattern<Literal> {
		self.repeat(count())
	}
}
