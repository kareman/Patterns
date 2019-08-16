//
//  TextPattern.swift
//  Patterns
//
//  Created by Kåre Morstøl on 20/03/2017.
//
//

import Foundation

public typealias ParsedRange = Range<TextPattern.Input.Index>

public protocol TextPattern: CustomStringConvertible {
	typealias Input = Substring

	func parse(_ input: Input, at index: Input.Index, using: inout Patterns.ParseData) -> ParsedRange?
	func parse(_ input: Input, from index: Input.Index, using: inout Patterns.ParseData) -> ParsedRange?
	func _prepForPatterns(remainingPatterns: inout ArraySlice<TextPattern>) throws -> Patterns.Patternette
	/// The length this pattern always parses, if it is constant
	var length: Int? { get }
	var regex: String { get }
}

public protocol TextPatternWrapper: TextPattern {
	var pattern: TextPattern { get }
}

public extension TextPatternWrapper {
	func parse(_ input: Input, at index: Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		return self.parse(input, at: index, using: &data)
	}

	func parse(_ input: Input, from index: Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		return self.parse(input, from: index, using: &data)
	}

	func _prepForPatterns(remainingPatterns: inout ArraySlice<TextPattern>) throws -> Patterns.Patternette {
		return try pattern._prepForPatterns(remainingPatterns: &remainingPatterns)
	}

	/// The length this pattern always parses, if it is constant
	var length: Int? {
		return pattern.length
	}

	var regex: String { return pattern.regex }
}

extension TextPattern {
	public func parse(_ input: Input, at startIndex: Input.Index) -> ParsedRange? {
		var data = Patterns.ParseData()
		return parse(input, at: startIndex, using: &data)
	}

	public func parse(_ input: Input, from startIndex: Input.Index) -> ParsedRange? {
		var data = Patterns.ParseData()
		return parse(input, from: startIndex, using: &data)
	}

	public func parse(_ input: Input, from startIndex: Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		var index = startIndex
		while index < input.endIndex {
			if let range = parse(input, at: index, using: &data) {
				return range
			}
			input.formIndex(after: &index)
		}
		return parse(input, at: index, using: &data)
	}

	public func _prepForPatterns(remainingPatterns _: inout ArraySlice<TextPattern>) throws -> Patterns.Patternette {
		return ({ (input: Input, index: Input.Index, data: inout Patterns.ParseData) in
			self.parse(input, at: index, using: &data)
		}, description)
	}
}

public struct Literal: TextPattern {
	public let substring: Input
	let searchCache: SearchCache<Input.Element>

	public var description: String {
		return #""\#(String(substring).replacingOccurrences(of: "\n", with: "\\n"))""#
	}

	public var regex: String {
		return NSRegularExpression.escapedPattern(for: String(substring))
	}

	public var length: Int? { return substring.count }

	public init<S: Sequence>(_ sequence: S) where S.Element == Character {
		self.substring = TextPattern.Input(sequence)
		self.searchCache = SearchCache(pattern: self.substring)
		assert(!self.substring.isEmpty, "Cannot have an empty Literal.")
	}

	public init(_ character: Character) {
		self.init(String(character))
	}

	public func parse(_ input: TextPattern.Input, at index: TextPattern.Input.Index, using _: inout Patterns.ParseData) -> ParsedRange? {
		return input[index ..< input.endIndex].starts(with: substring)
			? index ..< input.index(index, offsetBy: substring.count) : nil
	}

	public func parse(_ input: Input, from index: Input.Index, using _: inout Patterns.ParseData) -> ParsedRange? {
		return input.range(of: substring, from: index, cache: searchCache)
	}
}

extension Literal: ExpressibleByStringLiteral {
	public init(stringLiteral value: StaticString) {
		self.init(String(describing: value))
	}
}

public struct OneOf: TextPattern {
	public let set: Group<Input.Element>

	public let description: String
	public let regex: String
	public let length: Int? = 1

	public init(description: String, regex: String? = nil, set: Group<Input.Element>) {
		self.set = set
		self.description = description
		self.regex = regex ?? "NOT IMPLEMENTED"
	}

	public init(description: String, regex: String? = nil, contains: @escaping (Input.Element) -> Bool) {
		self.init(description: description, regex: regex, set: Group(contains: contains))
	}

	public init<S: Collection>(contentsOf characters: S) where S.Element == Input.Element {
		set = Group(contentsOf: characters)
		description = "\"\(set)\""
		regex = "[\(NSRegularExpression.escapedPattern(for: characters.map(String.init(describing:)).joined()))]"
	}

	public func parse(_ input: Input, at index: Input.Index, using _: inout Patterns.ParseData) -> ParsedRange? {
		return (index < input.endIndex && set.contains(input[index])) ? index ..< input.index(after: index) : nil
	}

	public static let basePatterns: [OneOf] = [
		alphanumeric, letter, lowercase, uppercase, punctuation, whitespace, newline, hexDigit, digit, ascii,
		symbol, mathSymbol, currencySymbol,
	]

	public static func patterns(for c: Input.Element) -> [TextPattern] {
		return OneOf.basePatterns.filter { $0.set.contains(c) }
	}

	public static func patterns<S: Sequence>(for s: S) -> [TextPattern] where S.Element == Input.Element {
		return OneOf.basePatterns.filter { $0.set.contains(contentsOf: s) }
	}
}

public struct RepeatPattern: TextPattern {
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
		return "\(repeatedPattern){\(min)...\(max.map(String.init) ?? "")}"
	}

	public var regex: String {
		return repeatedPattern.regex + "{\(min),\(max.map(String.init(describing:)) ?? "")}"
	}

	public var length: Int? {
		return min == max ? repeatedPattern.length.map { $0 * min } : nil
	}

	public func parse(_ input: Input, at startindex: Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		var index = startindex
		for _ in 0 ..< min {
			guard let nextindex = repeatedPattern.parse(input, at: index, using: &data)?.upperBound else { return nil }
			index = nextindex
		}
		for _ in min ..< (max ?? Int.max) {
			guard index < input.endIndex else { return startindex ..< index }
			guard let nextindex = repeatedPattern.parse(input, at: index, using: &data)?.upperBound else {
				return startindex ..< index
			}
			index = nextindex
		}
		return startindex ..< index
	}

	/*
	 public func parse(_ input: Pattern.Input, from startindex: Pattern.Input.Index) -> ParsedRange? {
	 guard min > 0 else { return Pattern.parse(self, input, at: startindex) }
	 guard let firstrange = repeatedPattern.parse(input, from: startindex) else { return nil }
	 guard max > 1 else { return firstrange }
	 guard let therest = repeatedPattern.repeat(min: Swift.max(0, min-1), max: max-1).parse(input, at: firstrange.upperBound) else { return nil }
	 return firstrange.lowerBound..<therest.upperBound
	 }
	 */
}

extension TextPattern {
	public func `repeat`<R: RangeExpression>(_ range: R) -> TextPattern where R.Bound == Int {
		return RepeatPattern(repeatedPattern: self, range: range)
	}
}

public struct OrPattern: TextPattern {
	public let pattern1, pattern2: TextPattern

	init(pattern1: TextPattern, pattern2: TextPattern) {
		self.pattern1 = pattern1 is Capture ? Patterns(pattern1) : pattern1
		self.pattern2 = pattern2 is Capture ? Patterns(pattern2) : pattern2
	}

	public var description: String {
		return "(\(pattern1) || \(pattern2))"
	}

	public var regex: String {
		return pattern1.regex + "|" + pattern2.regex
	}

	public var length: Int? {
		return pattern1.length == pattern2.length ? pattern1.length : nil
	}

	public func parse(_ input: Input, from startindex: Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		// TODO: should pattern1 always win if it succeeds, even if pattern2 succeeds earlier?
		let result1 = pattern1.parse(input, from: startindex, using: &data)
		let result2 = pattern2.parse(input, from: startindex, using: &data)
		if result1?.lowerBound == result2?.lowerBound { return result1 }
		return [result1, result2].compactMap { $0 }.sorted(by: <).first
	}

	public func parse(_ input: Input, at index: Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		// TODO: Is this the only place where changes to `data` may have to be undone?
		// Should all patterns be required to not change `data` if failing?
		let backup = data
		if let result1 = pattern1.parse(input, at: index, using: &data) {
			return result1
		}
		data = backup
		return pattern2.parse(input, at: index, using: &data)
	}
}

public func || (p1: TextPattern, p2: TextPattern) -> OrPattern {
	return OrPattern(pattern1: p1, pattern2: p2)
}

public struct Line: TextPatternWrapper {
	public let description: String = "line"
	public let regex: String = "^.*$"
	public let pattern: TextPattern
	public let start = Start()
	public let end = End()

	init() {
		pattern = Patterns(Start(), Skip(), End())
	}

	public struct Start: TextPattern {
		public init() {}

		public var description: String { return "line.start" }
		public var regex = "^"
		public var length: Int? = 0

		public func parse(_ input: TextPattern.Input, at startindex: TextPattern.Input.Index, using _: inout Patterns.ParseData) -> ParsedRange? {
			return startindex == input.startIndex || input[input.index(before: startindex)].isNewline
				? startindex ..< startindex
				: nil
		}

		public func parse(_ input: Input, from startIndex: Input.Index, using _: inout Patterns.ParseData) -> ParsedRange? {
			guard startIndex != input.startIndex else { return startIndex ..< startIndex }
			return input[input.index(before: startIndex)...].firstIndex(where: (\Character.isNewline).toFunc)
				.map(input.index(after:))
				.map { $0 ..< $0 }
		}
	}

	public struct End: TextPattern {
		public init() {}

		public var description: String { return "line.end" }
		public let regex = "$"
		public let length: Int? = 0

		public func parse(_ input: TextPattern.Input, at startindex: TextPattern.Input.Index, using _: inout Patterns.ParseData) -> ParsedRange? {
			if startindex == input.endIndex || input[startindex].isNewline {
				return startindex ..< startindex
			}
			return nil
		}

		public func parse(_ input: Input, from startIndex: Input.Index, using _: inout Patterns.ParseData) -> ParsedRange? {
			return input[startIndex...].firstIndex(where: (\Character.isNewline).toFunc).map { $0 ..< $0 }
				?? input.endIndex ..< input.endIndex
		}
	}
}

public struct NotPattern: TextPattern {
	public let pattern: TextPattern
	public var description: String {
		return "!\(pattern)"
	}

	public var regex: String {
		assertionFailure()
		return "NOT IMPLEMENTED"
	}

	public let length: Int? = 1

	public func parse(_ input: Input, at index: Input.Index, using data: inout Patterns.ParseData) -> ParsedRange? {
		guard let nextIndex = input.index(index, offsetBy: 1, limitedBy: input.endIndex) else {
			return nil
		}
		return pattern.parse(input, at: index, using: &data) == nil ? index ..< nextIndex : nil
	}
}

extension TextPattern {
	public var not: NotPattern {
		return NotPattern(pattern: self)
	}
}

public let alphanumeric = OneOf(description: "alphanumeric", regex: #"(?:\p{Alphabetic}|\p{Nd})"#,
                                contains: { $0.isWholeNumber || $0.isLetter })
public let digit = OneOf(description: "digit", regex: #"\p{Nd}"#,
                         contains: (\Character.isWholeNumber).toFunc)
public let letter = OneOf(description: "letter", regex: #"\p{Alphabetic}"#,
                          contains: (\Character.isLetter).toFunc)
public let lowercase = OneOf(description: "lowercase", regex: #"\p{Ll}"#,
                             contains: (\Character.isLowercase).toFunc)
public let newline = OneOf(description: "newline", regex: #"\p{Zl}"#,
                           contains: (\Character.isNewline).toFunc)
public let punctuation = OneOf(description: "punctuation", regex: #"\p{P}"#,
                               contains: (\Character.isPunctuation).toFunc)
public let symbol = OneOf(description: "symbol", regex: #"\p{S}"#,
                          contains: (\Character.isSymbol).toFunc)
public let uppercase = OneOf(description: "uppercase", regex: #"\p{Lu}"#,
                             contains: (\Character.isUppercase).toFunc)
public let whitespace = OneOf(description: "whitespace", regex: #"\p{White_Space}"#,
                              contains: (\Character.isWhitespace).toFunc)

public let hexDigit = OneOf(description: "hexDigit", regex: #"\p{Hex_Digit}"#,
                            contains: (\Character.isHexDigit).toFunc)

public let ascii = OneOf(description: "ascii", regex: #"[[:ascii:]]"#,
                         contains: (\Character.isASCII).toFunc) // regex might also be [ -~] or [\x00-\x7F]

public let mathSymbol = OneOf(description: "mathSymbol", regex: #"\p{Sm}"#,
                              contains: (\Character.isMathSymbol).toFunc)

public let currencySymbol = OneOf(description: "currencySymbol", regex: #"\p{Sc}"#,
                                  contains: (\Character.isCurrencySymbol).toFunc)

public let line = Line()
