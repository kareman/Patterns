//
//  Repetition.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

/// Repeats the `wrapped` pattern `min` times, then repeats it optionally `max-min` times.
/// Or an unlimited number of times if max is nil.
///
/// Used by operators `*+¿`.
public struct RepeatPattern<Wrapped: Pattern>: Pattern {
	public typealias Input = Wrapped.Input
	public let wrapped: Wrapped
	public let min: Int
	public let max: Int?

	@inlinable
	init<R: RangeExpression>(_ wrapped: Wrapped, range: R) where R.Bound == Int {
		let actualRange = range.relative(to: Int.zero ..< Int.max)
		self.wrapped = wrapped
		self.min = actualRange.lowerBound
		self.max = actualRange.upperBound == Int.max ? nil : actualRange.upperBound - 1
	}

	public var description: String {
		"\(wrapped){\(min)...\(max.map(String.init) ?? "")}"
	}

	@inlinable
	public func createInstructions(_ instructions: inout Instructions) throws {
		let repeatedInstructions = try wrapped.createInstructions()
		for _ in 0 ..< min { instructions.append(contentsOf: repeatedInstructions) }
		if let max = max {
			let optionalRepeatedInstructions = Instructions {
				$0.append(.choice(offset: repeatedInstructions.count + 2))
				$0.append(contentsOf: repeatedInstructions)
				$0.append(.commit)
			}
			instructions.append(contentsOf: repeatElement(optionalRepeatedInstructions, count: max - min).lazy.flatMap { $0 })
		} else {
			instructions.append {
				$0.append(.choice(offset: repeatedInstructions.count + 3))
				$0.append(contentsOf: repeatedInstructions)
				$0.append(.commit)
				$0.append(.jump(offset: -repeatedInstructions.count - 2))
			}
		}
	}
}

extension Pattern {
	/// Repeats this pattern from `range.lowerBound` to `range.upperBound` times.
	@inlinable
	public func `repeat`<R: RangeExpression>(_ range: R) -> RepeatPattern<Self> where R.Bound == Int {
		return RepeatPattern(self, range: range)
	}

	/// Repeats this pattern `count` times.
	@inlinable
	public func `repeat`(_ count: Int) -> RepeatPattern<Self> {
		RepeatPattern(self, range: count ... count)
	}
}

postfix operator *

/// Repeats the preceding pattern 0 or more times.
@inlinable
public postfix func * <P: Pattern>(me: P) -> RepeatPattern<P> {
	me.repeat(0...)
}

/// Repeats the preceding pattern 0 or more times.
@inlinable
public postfix func * (me: Literal) -> RepeatPattern<Literal> {
	me.repeat(0...)
}

postfix operator +

/// Repeats the preceding pattern 1 or more times.
@inlinable
public postfix func + <P: Pattern>(me: P) -> RepeatPattern<P> {
	me.repeat(1...)
}

/// Repeats the preceding pattern 1 or more times.
@inlinable
public postfix func + (me: String) -> RepeatPattern<Literal<String>> {
	Literal(me).repeat(1...)
}

postfix operator ¿

/// Tries the preceding pattern, and continues even if it fails.
@inlinable
public postfix func ¿ <P: Pattern>(me: P) -> RepeatPattern<P> {
	me.repeat(0 ... 1)
}

/// Tries the preceding pattern, and continues even if it fails.
@inlinable
public postfix func ¿ (me: Literal) -> RepeatPattern<Literal> {
	me.repeat(0 ... 1)
}
