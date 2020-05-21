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
		assert(!self.substring.isEmpty, "Cannot have an empty Literal.")
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

public func • (lhs: Literal, rhs: TextPattern) -> ConcatenationPattern {
	ConcatenationPattern(first: lhs, second: rhs)
}

public func • (lhs: TextPattern, rhs: Literal) -> ConcatenationPattern {
	ConcatenationPattern(first: lhs, second: rhs)
}

public func || (p1: Literal, p2: TextPattern) -> OrPattern {
	return OrPattern(pattern1: p1, pattern2: p2)
}

public func || (p1: TextPattern, p2: Literal) -> OrPattern {
	return OrPattern(pattern1: p1, pattern2: p2)
}

public func || (p1: Literal, p2: Literal) -> OrPattern {
	return OrPattern(pattern1: p1, pattern2: p2)
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

public struct RepeatPattern: TextPattern, RegexConvertible {
	public let repeatedPattern: TextPattern
	public let min: Int
	public let max: Int?

	init<R: RangeExpression>(repeatedPattern: TextPattern, range: R) where R.Bound == Int {
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
	public func `repeat`<R: RangeExpression>(_ range: R) -> RepeatPattern where R.Bound == Int {
		return RepeatPattern(repeatedPattern: self, range: range)
	}

	public func `repeat`(_ count: Int) -> RepeatPattern {
		return RepeatPattern(repeatedPattern: self, range: count ... count)
	}
}

postfix operator *

public postfix func *(me: TextPattern) -> RepeatPattern {
	me.repeat(0...)
}

public postfix func *(me: Literal) -> RepeatPattern {
	me.repeat(0...)
}

postfix operator +

public postfix func +(me: TextPattern) -> RepeatPattern {
	me.repeat(1...)
}

public postfix func +(me: Literal) -> RepeatPattern {
	me.repeat(1...)
}

postfix operator ¿

public postfix func ¿(me: TextPattern) -> RepeatPattern {
	me.repeat(0...1)
}

public postfix func ¿(me: Literal) -> RepeatPattern {
	me.repeat(0...1)
}


public struct OrPattern: TextPattern, RegexConvertible {
	public let pattern1, pattern2: TextPattern

	init(pattern1: TextPattern, pattern2: TextPattern) {
		self.pattern1 = pattern1 is Capture ? Patterns(pattern1) : pattern1
		self.pattern2 = pattern2 is Capture ? Patterns(pattern2) : pattern2
	}

	public var description: String {
		return "(\(pattern1) || \(pattern2))"
	}

	public var regex: String {
		return (pattern1 as! RegexConvertible).regex + "|" + (pattern2 as! RegexConvertible).regex
	}

	public func createInstructions() -> [Instruction] {
		let (inst1, inst2) = (pattern1.createInstructions(), pattern2.createInstructions())
		return Array<Instruction> {
			$0 += .split(first: 1, second: inst1.count + 3)
			$0 += inst1
			$0 += .cancelLastSplit
			$0 += .jump(relative: inst2.count + 1)
			$0 += inst2
		}
	}
}

public func || (p1: TextPattern, p2: TextPattern) -> OrPattern {
	return OrPattern(pattern1: p1, pattern2: p2)
}

public struct Line: TextPattern, RegexConvertible {
	public let description: String = "line"
	public let regex: String = "^.*$"

	public let pattern: TextPattern
	public static let start = Start()
	public static let end = End()

	public init() {
		pattern = Patterns(Start(), Skip(), End())
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
