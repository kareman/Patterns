//
//  SwiftPattern.swift
//  Patterns
//
//  Created by Kåre Morstøl on 20/03/2017.
//
//

import Foundation

public typealias ParsedRange = Range<TextPattern.Input.Index>

public struct Literal: TextPattern, RegexConvertible {
	public let substring: Input
	let searchCache: SearchCache<Input.Element>

	public var description: String {
		return #""\#(String(substring).replacingOccurrences(of: "\n", with: "\\n"))""#
	}

	public var regex: String {
		return NSRegularExpression.escapedPattern(for: String(substring))
	}

	public init<S: Sequence>(_ sequence: S) where S.Element == TextPattern.Input.Element {
		self.substring = TextPattern.Input(sequence)
		self.searchCache = SearchCache(pattern: self.substring)
	}

	public init(_ character: Character) {
		self.init(String(character))
	}

	public func createInstructions() -> [Instruction] {
		return substring.map(Instruction.literal)
	}
}

extension Literal: ExpressibleByStringLiteral {
	public init(stringLiteral value: StaticString) {
		self.init(String(describing: value))
	}
}

public struct OneOf: TextPattern, RegexConvertible {
	let group: Group<Input.Element>
	public let description: String
	private let _regex: String?
	public var regex: String {
		_regex ?? fatalError("Regex not provided for '\(description)'")
	}

	public init(description: String, regex: String? = nil, group: Group<Input.Element>) {
		self.group = group
		self.description = description
		self._regex = regex
	}

	public init(description: String, regex: String? = nil, contains: @escaping (Input.Element) -> Bool) {
		self.init(description: description, regex: regex, group: Group(contains: contains))
	}

	public init<S: Sequence>(_ characters: S) where S.Element == Input.Element {
		group = Group(contentsOf: characters)
		description = "\"\(group)\""
		_regex = "[\(NSRegularExpression.escapedPattern(for: characters.map(String.init(describing:)).joined()))]"
	}

	public static let basePatterns: [OneOf] = [
		any, alphanumeric, letter, lowercase, uppercase, punctuation, whitespace, newline, hexDigit, digit,
		ascii, symbol, mathSymbol, currencySymbol,
	]

	public static func patterns(for c: Input.Element) -> [TextPattern] {
		OneOf.basePatterns.filter { $0.group.contains(c) }
	}

	public static func patterns<S: Sequence>(for s: S) -> [TextPattern] where S.Element == Input.Element {
		OneOf.basePatterns.filter { $0.group.contains(contentsOf: s) }
	}

	public func createInstructions() -> [Instruction] {
		[.checkCharacter(group.contains)]
	}

	public static func + (lhs: OneOf, rhs: OneOf) -> OneOf {
		OneOf(description: "\(lhs) + \(rhs)", group: lhs.group.union(rhs.group))
	}

	public static func - (lhs: OneOf, rhs: OneOf) -> OneOf {
		OneOf(description: "\(lhs) - \(rhs)", group: lhs.group.subtracting(rhs.group))
	}
}

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

	public func createInstructions() -> [Instruction] {
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

public struct OrPattern<First: TextPattern, Second: TextPattern>: TextPattern {
	public let first: First
	public let second: Second

	init(_ first: First, or second: Second) {
		self.first = first
		self.second = second
	}

	public var description: String {
		return "(\(first) / \(second))"
	}

	public func createInstructions() -> [Instruction] {
		let (inst1, inst2) = (first.createInstructions(), second.createInstructions())
		return Array<Instruction> {
			$0 += .split(first: 1, second: inst1.count + 3)
			$0 += inst1
			$0 += .cancelLastSplit
			$0 += .jump(relative: inst2.count + 1)
			$0 += inst2
		}
	}
}

extension OrPattern: RegexConvertible where First: RegexConvertible, Second: RegexConvertible {
	public var regex: String {
		return first.regex + "|" + second.regex
	}
}

public func / <First: TextPattern, Second: TextPattern>(p1: First, p2: Second) -> OrPattern<First, Second> {
	return OrPattern(p1, or: p2)
}

public func / <Second: TextPattern>(p1: Literal, p2: Second) -> OrPattern<Literal, Second> {
	return OrPattern(p1, or: p2)
}

public func / <First: TextPattern>(p1: First, p2: Literal) -> OrPattern<First, Literal> {
	return OrPattern(p1, or: p2)
}

public func / (p1: Literal, p2: Literal) -> OrPattern<Literal, Literal> {
	return OrPattern(p1, or: p2)
}

public struct Line: TextPattern, RegexConvertible {
	public let description: String = "line"
	public let regex: String = "^.*$"

	public let pattern: TextPattern
	public static let start = Start()
	public static let end = End()

	public init() {
		pattern = Start() • Skip() • End()
	}

	public func createInstructions() -> [Instruction] {
		pattern.createInstructions()
	}

	public struct Start: TextPattern, RegexConvertible {
		public init() {}

		public var description: String { "line.start" }
		public var regex = "^"

		public func parse(_ input: Input, at index: Input.Index) -> Bool {
			index == input.startIndex || input[input.index(before: index)].isNewline
		}

		public func createInstructions() -> [Instruction] {
			[.checkIndex(self.parse(_:at:))]
		}
	}

	public struct End: TextPattern, RegexConvertible {
		public init() {}

		public var description: String { "line.end" }
		public let regex = "$"

		public func parse(_ input: Input, at index: Input.Index) -> Bool {
			index == input.endIndex || input[index].isNewline
		}

		public func createInstructions() -> [Instruction] {
			[.checkIndex(self.parse(_:at:))]
		}
	}
}

public struct NotPattern: TextPattern {
	public let pattern: TextPattern
	public var description: String { "!\(pattern)" }

	public func createInstructions() -> [Instruction] {
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
	public var not: NotPattern { NotPattern(pattern: self) }

	public static prefix func ! (me: Self) -> NotPattern {
		me.not
	}
}

public prefix func ! (me: Literal) -> NotPattern {
	me.not
}

public let any = OneOf(description: "any", regex: #"[.\p{Zl}]"#,
                       contains: { _ in true })
public let alphanumeric = OneOf(description: "alphanumeric", regex: #"(?:\p{Alphabetic}|\p{Nd})"#,
                                contains: { $0.isWholeNumber || $0.isLetter })
public let digit = OneOf(description: "digit", regex: #"\p{Nd}"#,
                         contains: \Character.isWholeNumber)
public let letter = OneOf(description: "letter", regex: #"\p{Alphabetic}"#,
                          contains: \Character.isLetter)
public let lowercase = OneOf(description: "lowercase", regex: #"\p{Ll}"#,
                             contains: \Character.isLowercase)
public let newline = OneOf(description: "newline", regex: #"\p{Zl}"#,
                           contains: \Character.isNewline)
public let punctuation = OneOf(description: "punctuation", regex: #"\p{P}"#,
                               contains: \Character.isPunctuation)
public let symbol = OneOf(description: "symbol", regex: #"\p{S}"#,
                          contains: \Character.isSymbol)
public let uppercase = OneOf(description: "uppercase", regex: #"\p{Lu}"#,
                             contains: \Character.isUppercase)
public let whitespace = OneOf(description: "whitespace", regex: #"\p{White_Space}"#,
                              contains: \Character.isWhitespace)
public let hexDigit = OneOf(description: "hexDigit", regex: #"\p{Hex_Digit}"#,
                            contains: \Character.isHexDigit)
public let ascii = OneOf(description: "ascii", regex: #"[[:ascii:]]"#,
                         contains: \Character.isASCII) // regex might also be [ -~] or [\x00-\x7F]
public let mathSymbol = OneOf(description: "mathSymbol", regex: #"\p{Sm}"#,
                              contains: \Character.isMathSymbol)
public let currencySymbol = OneOf(description: "currencySymbol", regex: #"\p{Sc}"#,
                                  contains: \Character.isCurrencySymbol)
