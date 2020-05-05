//
//  SwiftEngine.swift
//
//
//  Created by Kåre Morstøl on 19/04/2020.
//

#if SwiftEngine

public protocol SwiftPattern: CustomStringConvertible {
	typealias Input = Substring

	func parse(_ input: Input, at index: Input.Index, using: inout PatternsEngine.ParseData) -> ParsedRange?
	func parse(_ input: Input, from index: Input.Index, using: inout PatternsEngine.ParseData) -> ParsedRange?
	func _prepForPatterns(remainingPatterns: inout ArraySlice<SwiftPattern>) throws -> PatternsEngine.Patternette
	/// The length this pattern always parses, if it is constant
	var length: Int? { get }
	var regex: String { get }
}

public protocol SwiftPatternWrapper: SwiftPattern {
	var pattern: SwiftPattern { get }
}

public extension SwiftPatternWrapper {
	func parse(_ input: Input, at index: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		return self.parse(input, at: index, using: &data)
	}

	func parse(_ input: Input, from index: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		return self.parse(input, from: index, using: &data)
	}

	func _prepForPatterns(remainingPatterns: inout ArraySlice<SwiftPattern>) throws -> PatternsEngine.Patternette {
		return try pattern._prepForPatterns(remainingPatterns: &remainingPatterns)
	}

	/// The length this pattern always parses, if it is constant
	var length: Int? {
		return pattern.length
	}

	var regex: String { return pattern.regex }
}

extension SwiftPattern {
	public func parse(_ input: Input, at startIndex: Input.Index) -> ParsedRange? {
		var data = PatternsEngine.ParseData()
		return parse(input, at: startIndex, using: &data)
	}

	public func parse(_ input: Input, from startIndex: Input.Index) -> ParsedRange? {
		var data = PatternsEngine.ParseData()
		return parse(input, from: startIndex, using: &data)
	}

	public func parse(_ input: Input, from startIndex: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		var index = startIndex
		while index < input.endIndex {
			if let range = parse(input, at: index, using: &data) {
				return range
			}
			input.formIndex(after: &index)
		}
		return parse(input, at: index, using: &data)
	}

	public func _prepForPatterns(remainingPatterns _: inout ArraySlice<SwiftPattern>) throws -> PatternsEngine.Patternette {
		return ({ (input: Input, index: Input.Index, data: inout PatternsEngine.ParseData) in
			self.parse(input, at: index, using: &data)
		}, description)
	}
}

extension Literal: SwiftPattern {
	public var length: Int? { return substring.count }

	public func parse(_ input: SwiftPattern.Input, at index: SwiftPattern.Input.Index, using _: inout PatternsEngine.ParseData) -> ParsedRange? {
		return input[index ..< input.endIndex].starts(with: substring)
			? index ..< input.index(index, offsetBy: substring.count) : nil
	}

	public func parse(_ input: Input, from index: Input.Index, using _: inout PatternsEngine.ParseData) -> ParsedRange? {
		return input.range(of: substring, from: index, cache: searchCache)
	}
}

extension OneOf: SwiftPattern {
	public var length: Int? { 1 }

	public func parse(_ input: Input, at index: Input.Index, using _: inout PatternsEngine.ParseData) -> ParsedRange? {
		return (index < input.endIndex && set.contains(input[index])) ? index ..< input.index(after: index) : nil
	}
}

extension RepeatPattern: SwiftPattern {
	public var length: Int? {
		return min == max ? repeatedPattern.length.map { $0 * min } : nil
	}

	public func parse(_ input: Input, at startindex: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
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

extension OrPattern: SwiftPattern {
	public var length: Int? {
		return pattern1.length == pattern2.length ? pattern1.length : nil
	}

	public func parse(_ input: Input, from startindex: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		// TODO: should pattern1 always win if it succeeds, even if pattern2 succeeds earlier?
		let result1 = pattern1.parse(input, from: startindex, using: &data)
		let result2 = pattern2.parse(input, from: startindex, using: &data)
		if result1?.lowerBound == result2?.lowerBound { return result1 }
		return [result1, result2].compactMap { $0 }.sorted(by: <).first
	}

	public func parse(_ input: Input, at index: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
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

extension Line: SwiftPattern {
	public var length: Int? { nil }

	public func parse(_ input: Input, at index: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		pattern.parse(input, at: index, using: &data)
	}

	public func parse(_ input: Input, from startIndex: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		pattern.parse(input, from: startIndex, using: &data)
	}
}

extension Line.Start: SwiftPattern {
	public var length: Int? { 0 }

	public func parse(_ input: Input, at index: Input.Index, using _: inout PatternsEngine.ParseData) -> ParsedRange? {
		return index == input.startIndex || input[input.index(before: index)].isNewline
			? index ..< index
			: nil
	}

	public func parse(_ input: Input, from startIndex: Input.Index, using _: inout PatternsEngine.ParseData) -> ParsedRange? {
		guard startIndex != input.startIndex else { return startIndex ..< startIndex }
		return input[input.index(before: startIndex)...].firstIndex(where: \.isNewline)
			.map(input.index(after:))
			.map { $0 ..< $0 }
	}
}

extension Line.End: SwiftPattern {
	public var length: Int? { 0 }

	public func parse(_ input: Input, at index: Input.Index, using _: inout PatternsEngine.ParseData) -> ParsedRange? {
		if index == input.endIndex || input[index].isNewline {
			return index ..< index
		}
		return nil
	}

	public func parse(_ input: Input, from startIndex: Input.Index, using _: inout PatternsEngine.ParseData) -> ParsedRange? {
		return input[startIndex...].firstIndex(where: \.isNewline).map { $0 ..< $0 }
			?? input.endIndex ..< input.endIndex
	}
}

extension NotPattern: SwiftPattern {
	public var length: Int? { 1 }

	public func parse(_ input: Input, at index: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		guard let nextIndex = input.index(index, offsetBy: 1, limitedBy: input.endIndex) else {
			return nil
		}
		return pattern.parse(input, at: index, using: &data) == nil ? index ..< nextIndex : nil
	}
}
#endif
