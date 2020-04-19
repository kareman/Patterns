//
//  SwiftEngine-Patterns.swift
//
//
//  Created by Kåre Morstøl on 19/04/2020.
//

#if SwiftEngine

extension Skip: SwiftPattern {
	public let length: Int? = nil

	public func parse(_: SwiftPattern.Input, at _: SwiftPattern.Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func parse(_: SwiftPattern.Input, from _: SwiftPattern.Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func _prepForPatterns(remainingPatterns: inout ArraySlice<SwiftPattern>)
		throws -> PatternsEngine.Patternette {
		func getBoundHandler(_ remainingPatterns: inout ArraySlice<SwiftPattern>)
			-> (Input, Input.Index, inout PatternsEngine.ParseData) -> Void {
			switch remainingPatterns.first {
			case is Capture.Start, is Capture.End:
				let me = remainingPatterns.removeFirst()
				return {
					var forgetAboutIt = ArraySlice<SwiftPattern>()
					try! _ = me._prepForPatterns(remainingPatterns: &forgetAboutIt).pattern($0, $1, &$2)
				}
			default:
				return { _, _, _ in }
			}
		}

		let maybeStoreBound = getBoundHandler(&remainingPatterns)

		guard let next = remainingPatterns.first else {
			return ({ (input, index, bounds: inout PatternsEngine.ParseData) in
				// TODO: remove because it's never used
				maybeStoreBound(input, input.endIndex, &bounds)
				return index ..< input.endIndex
			}, description + " (to the end)")
		}
		guard !(next is Skip) else {
			throw Patterns.InitError.message("Cannot have 2 Skip in a row.")
		}

		return ({ (input, index, bounds: inout PatternsEngine.ParseData) in
			guard let nextRange = next.parse(input, from: index, using: &bounds) else { return nil }
			if let repeatedPattern = self.repeatedPattern {
				guard repeatedPattern.parse(input[index ..< nextRange.lowerBound], at: index, using: &bounds)?.upperBound == nextRange.lowerBound else { return nil }
			}
			maybeStoreBound(input, nextRange.lowerBound, &bounds)
			return index ..< nextRange.lowerBound
		}, description)
	}
}

extension Capture: SwiftPattern {
	public var length: Int?

	public func parse(_: TextPattern.Input, at _: TextPattern.Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func parse(_: TextPattern.Input, from _: TextPattern.Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	/*
	 public func _prepForPatterns(remainingPatterns: inout ArraySlice<TextPattern>) throws -> Patterns.Patternette {
	 	remainingPatterns.insert(contentsOf: patterns + [Capture.End()], at: remainingPatterns.startIndex)
	 	return try Capture.Start()._prepForPatterns(remainingPatterns: &remainingPatterns)
	 }
	 */
}

extension Capture.Start: SwiftPattern {
	public let length: Int? = 0

	public func parse(_: TextPattern.Input, from _: TextPattern.Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func parse(_: Input, at index: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		data.captureBeginnings.append((name, index))
		return index ..< index
	}
}

extension Capture.End: SwiftPattern {
	public let length: Int? = 0

	public func parse(_: TextPattern.Input, from _: TextPattern.Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		assertionFailure("do not call this"); return nil
	}

	public func parse(_: Input, at index: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		if let (name, begin) = data.captureBeginnings.popLast() {
			data.captures.append((name, begin ..< index))
		} else {
			data.captures.append((nil, index ..< index))
		}
		return index ..< index
	}
}

public class PatternsEngine: Matcher {
	public struct ParseData {
		var captureBeginnings = ContiguousArray<(name: String?, begin: Patterns.Input.Index)>()
		var captures = ContiguousArray<(name: String?, range: ParsedRange)>()
	}

	public typealias Patternette =
		(pattern: (Patterns.Input, Patterns.Input.Index, inout ParseData) -> ParsedRange?, description: String)
	private let patternettes: [Patternette]
	private let patternFrom: SwiftPattern?

	private static func createPatternettes(_ patterns: [SwiftPattern]) throws -> [Patternette] {
		var remainingPatterns = patterns[...]
		var result = [Patternette]()
		while let nextPattern = remainingPatterns.popFirst() {
			if !(nextPattern is Capture.Start || nextPattern is Capture.End), nextPattern.length == 0, let first = remainingPatterns.first {
				if type(of: nextPattern) == type(of: first) {
					throw Patterns.InitError.message("Cannot have 2 \(type(of: nextPattern)) in a row, as they will always parse the same position.")
				}
				if let second = remainingPatterns.second,
					type(of: nextPattern) == type(of: second),
					first.length == 0 || (first as? Skip)?.repeatedPattern == nil {
					throw Patterns.InitError.message("Cannot have 2 \(type(of: nextPattern)) with a \(first) in between, as they will always parse the same position.")
				}
			}
			result.append(try nextPattern._prepForPatterns(remainingPatterns: &remainingPatterns))
		}
		return result
	}

	required init(_ series: [SwiftPattern]) throws {
		self.patternettes = try Self.createPatternettes(series)

		// find first parseable pattern 'patternFrom', if there is no Skip pattern before it use it in Self.parse(_:from:):
		let patternFromIndex = series.firstIndex(where: { !($0 is Skip || $0 is Capture || $0 is Capture.Start || $0 is Capture.End) })!
		let patternFrom = series[patternFromIndex]
		if let firstSkipIndex = series.firstIndex(where: { $0 is Skip }), firstSkipIndex < patternFromIndex {
			self.patternFrom = nil
		} else {
			if let patternFromAsPatterns = patternFrom as? Patterns {
				self.patternFrom = (patternFromAsPatterns.matcher as! PatternsEngine).patternFrom
			} else {
				self.patternFrom = patternFrom
			}
		}
	}

	public func parse(_ input: Patterns.Input, at startindex: Patterns.Input.Index, using data: inout ParseData) -> ParsedRange? {
		var index = startindex
		for patternette in patternettes {
			guard let range = patternette.pattern(input, index, &data) else { return nil }
			index = range.upperBound
		}
		return startindex ..< index
	}

	internal func match(in input: Patterns.Input, at startindex: Patterns.Input.Index) -> Patterns.Match? {
		var data = PatternsEngine.ParseData()
		var index = startindex
		for patternette in patternettes {
			guard let range = patternette.pattern(input, index, &data) else { return nil }
			index = range.upperBound
		}

		return Patterns.Match(fullRange: startindex ..< index, data: data)
	}

	internal func match(in input: Patterns.Input, from startIndex: Patterns.Input.Index) -> Patterns.Match? {
		guard let patternFrom = patternFrom else { return self.match(in: input, at: startIndex) }
		var index = startIndex
		var data = PatternsEngine.ParseData()
		while index <= input.endIndex {
			guard let fromIndex = patternFrom.parse(input, from: index, using: &data)?.lowerBound else { return nil }
			if let match = self.match(in: input, at: fromIndex) {
				return match
			}
			guard fromIndex != input.endIndex else { return nil }
			index = input.index(after: fromIndex)
		}
		return nil
	}
}

extension Patterns: SwiftPattern {
	public var length: Int? {
		let lengths = series.compactMap(\.length)
		return lengths.count == series.count ? lengths.reduce(0, +) : nil
	}

	public func parse(_ input: Input, at startindex: Input.Index, using data: inout PatternsEngine.ParseData) -> ParsedRange? {
		return matcher.parse(input, at: startindex, using: &data)
	}
}

extension Patterns.Match {
	init(fullRange: ParsedRange, data: PatternsEngine.ParseData) {
		let captures = (data.captureBeginnings.map { ($0, $1 ..< $1) } + data.captures).sorted(by: { $0.range < $1.range })
		self.init(fullRange: fullRange, captures: captures)
	}
}

#endif
