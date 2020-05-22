//
//  Patterns.swift
//  Patterns
//
//  Created by Kåre Morstøl on 23/10/2018.
//

public struct Skip: TextPattern, RegexConvertible {
	public let repeatedPattern: TextPattern?
	public let description: String
	public var regex: String {
		return repeatedPattern.map { "(?:\(($0 as! RegexConvertible).regex))*?" } ?? ".*?"
	}

	public init(whileRepeating repeatedPattern: TextPattern? = nil) {
		self.repeatedPattern = repeatedPattern
		self.description = "\(repeatedPattern.map(String.init(describing:)) ?? "")*"
	}

	public func createInstructions() -> [Instruction] {
		let reps = repeatedPattern?.repeat(0...).createInstructions() ?? [.any]
		return [.split(first: reps.count + 2, second: 1)]
			+ reps
			+ [.jump(relative: -reps.count - 1)]
	}
}

public struct Capture: TextPattern, RegexConvertible {
	public var description: String = "CAPTURE" // TODO: proper description
	public let name: String?
	public let patterns: [TextPattern]

	public var regex: String {
		let capturedRegex = patterns.map { ($0 as! RegexConvertible).regex }.joined()
		return name.map { "(?<\($0)>\(capturedRegex))" } ?? "(\(capturedRegex))"
	}

	public init(name: String? = nil, _ patterns: [TextPattern]) {
		self.patterns = patterns
		self.name = name
	}

	public init(name: String? = nil, _ patterns: TextPattern...) {
		self.init(name: name, patterns)
	}

	public func createInstructions() -> [Instruction] {
		return [.captureStart(name: name)] + patterns.flatMap { $0.createInstructions() } + [.captureEnd]
	}

	public struct Start: TextPattern, RegexConvertible {
		public var description: String { return "[" }
		public var regex = "("
		public let name: String?

		public init(name: String? = nil) {
			self.name = name
		}

		public func createInstructions() -> [Instruction] {
			return [.captureStart(name: name)]
		}
	}

	public struct End: TextPattern, RegexConvertible {
		public var description: String { return "]" }
		public var regex = ")"

		public init() {}

		public func createInstructions() -> [Instruction] {
			return [.captureEnd]
		}
	}
}

protocol Matcher: class {
	func match(in input: TextPattern.Input, at startindex: TextPattern.Input.Index) -> Patterns.Match?
	func match(in input: TextPattern.Input, from startIndex: TextPattern.Input.Index) -> Patterns.Match?
}

public struct Patterns: TextPattern, RegexConvertible {
	public enum InitError: Error, CustomStringConvertible {
		case invalid([TextPattern])
		case message(String)

		public var description: String {
			switch self {
			case let .invalid(patterns):
				return "Invalid series of patterns: \(patterns)"
			case let .message(string):
				return string
			}
		}
	}

	public let series: [TextPattern]
	public let description: String
	#if SwiftEngine
	let matcher: PatternsEngine
	#else
	let matcher: VMBacktrackEngine
	#endif

	public var regex: String {
		return series.map { ($0 as! RegexConvertible).regex }.joined()
	}

	public init(_ pattern: TextPattern) throws {
		self.series = [pattern]
		self.matcher = try VMBacktrackEngine(self.series.first!)
		self.description = self.series.map(String.init(describing:)).joined(separator: " ")
	}

	public func ranges<S: StringProtocol>(in input: S, from startindex: TextPattern.Input.Index? = nil)
		-> AnySequence<ParsedRange> where S.SubSequence == TextPattern.Input {
		return AnySequence(matches(in: input, from: startindex).lazy.map(\.range))
	}

	public func createInstructions() -> [Instruction] {
		series.createInstructions()
	}
}

internal extension Sequence where Element == TextPattern {
	func createInstructions() -> [Instruction] {
		let series = Array(self)
		let splitBySkip = series.splitWhileKeepingSeparators(omittingEmptySubsequences: false, whereSeparator: { $0 is Skip })
		return (splitBySkip.first?.flatMap { $0.createInstructions() } ?? [])
			+ splitBySkip.dropFirst().flatMap {
				prependSkip(skip: $0.first! as! Skip, $0.dropFirst().flatMap { $0.createInstructions() })
			}
	}
}

internal func prependSkip<C: BidirectionalCollection>(skip: Skip = Skip(), _ instructions: C)
	-> [Instruction] where C.Element == Instruction {
	var remainingInstructions = instructions[...]
	var chars = [Instruction]()[...]
	var nonIndexMovers = [Instruction]()[...]
	var lastMoveTo = 0
	loop: while let inst = remainingInstructions.popFirst() {
		switch inst {
		case .literal, .checkCharacter:
			chars.append(inst)
		case .checkIndex, .captureStart, .captureEnd, .cancelLastSplit:
			let moveBy = chars.count - lastMoveTo
			if moveBy > 0 {
				nonIndexMovers.append(.moveIndex(relative: moveBy))
				lastMoveTo = chars.count
			}
			nonIndexMovers.append(inst)
		case .jump, .split, .match, .moveIndex, .function:
			remainingInstructions = instructions[instructions.index(before: remainingInstructions.startIndex)...]
			break loop
		}
	}
	if chars.count - lastMoveTo != 0 {
		nonIndexMovers.append(.moveIndex(relative: chars.count - lastMoveTo))
	}

	let search: (TextPattern.Input, TextPattern.Input.Index) -> TextPattern.Input.Index?
	let searchInstruction: Instruction

	switch chars.first {
	case nil:
		func isCheckIndex(_ inst: Instruction) -> Bool {
			if case .checkIndex = inst { return true } else { return false }
		}

		switch nonIndexMovers.popFirst(where: isCheckIndex(_:)) {
		case let .checkIndex(function):
			search = { input, index in
				input[index...].indices.first(where: { function(input, $0) })
					?? (function(input, input.endIndex) ? input.endIndex : nil)
			}
		default:
			return skip.createInstructions() + instructions
		}
	case let .checkCharacter(test):
		search = { input, index in input[index...].firstIndex(where: test) }
	case .literal:
		// TODO: mapWhile
		let cs: [Character] = chars.prefix(while: { if case .literal = $0 { return true } else { return false } })
			.map { if case let .literal(c) = $0 { return c } else { fatalError() } }
		if cs.count == 1 {
			search = { input, index in input[index...].firstIndex(of: cs[0]) }
		} else {
			let cache = SearchCache(pattern: cs)
			search = { input, index in input.range(of: cs, from: index, cache: cache)?.lowerBound }
		}
	default:
		fatalError()
	}

	if let repeatedPattern = skip.repeatedPattern {
		let skipInstructions = (repeatedPattern.repeat(0...).createInstructions() + [.match])[...]
		searchInstruction = .function { (input, thread) -> Bool in
			guard let end = search(input, thread.inputIndex) else { return false }
			guard let newThread = backtrackingVM(skipInstructions, input: input[..<end],
			                                     thread: Thread(startAt: skipInstructions.startIndex, withDataFrom: thread)),
				newThread.inputIndex == end else { return false }

			thread = Thread(startAt: thread.instructionIndex + 1, withDataFrom: newThread)
			return true
		}
	} else {
		searchInstruction = .search(search)
	}
	return Array<Instruction> {
		$0.reserveCapacity(chars.count + nonIndexMovers.count + remainingInstructions.count + 4)
		$0 += searchInstruction
		$0 += .split(first: 1, second: -1, atIndex: 1)
		$0 += chars
		$0 += .moveIndex(relative: -chars.count)
		$0 += nonIndexMovers
		$0 += remainingInstructions
		if skip.repeatedPattern != nil {
			$0 += .cancelLastSplit
		}
	}
}

extension Patterns {
	public struct Match {
		public let fullRange: ParsedRange
		public let captures: [(name: String?, range: ParsedRange)]

		init(fullRange: ParsedRange, captures: [(name: String?, range: ParsedRange)]) {
			self.fullRange = fullRange
			self.captures = captures
		}

		public var range: ParsedRange {
			captures.isEmpty ? fullRange : captures.first!.range.lowerBound ..< captures.last!.range.upperBound
		}

		public func description(using text: String) -> String {
			return """
			fullRange: \(text[fullRange])
			captures: \(captures.map { "\($0.name ?? "")\t\t\(text[$0.range])\n" })
			"""
		}

		public subscript(one name: String) -> ParsedRange? {
			return captures.first(where: { $0.name == name })?.range
		}

		public subscript(multiple name: String) -> [ParsedRange] {
			return captures.filter { $0.name == name }.map(\.range)
		}

		public var names: Set<String> { Set(captures.compactMap(\.name)) }
	}

	internal func match(in input: TextPattern.Input, at startindex: TextPattern.Input.Index) -> Match? {
		return matcher.match(in: input, at: startindex)
	}

	internal func match(in input: TextPattern.Input, from startIndex: TextPattern.Input.Index) -> Match? {
		return matcher.match(in: input, from: startIndex)
	}

	public func matches<S: StringProtocol>(in input: S, from startindex: TextPattern.Input.Index? = nil)
		-> UnfoldSequence<Match, TextPattern.Input.Index> where S.SubSequence == Substring {
		let input = input[...]
		var previousRange: ParsedRange?
		return sequence(state: startindex ?? input.startIndex, next: { (index: inout TextPattern.Input.Index) in
			guard let match = self.match(in: input, from: index),
				match.range != previousRange else { return nil }
			let range = match.range
			previousRange = range
			index = (range.isEmpty && range.upperBound != input.endIndex)
				? input.index(after: range.upperBound) : range.upperBound
			return match
		})
	}
}

extension Patterns: CustomDebugStringConvertible {
	public var debugDescription: String {
		return self.description
	}
}

