//
//  Patterns.swift
//  Patterns
//
//  Created by Kåre Morstøl on 23/10/2018.
//

public struct Skip<Repeated: TextPattern>: TextPattern, RegexConvertible {
	public let repeatedPattern: Repeated?
	public let description: String
	public var regex: String {
		return repeatedPattern.map { "(?:\(($0 as! RegexConvertible).regex))*?" } ?? ".*?"
	}

	public init(whileRepeating repeatedPattern: Repeated) {
		self.repeatedPattern = repeatedPattern
		self.description = "Skip(\(repeatedPattern))"
	}

	public func createInstructions() -> [Instruction<Input>] {
		let reps = repeatedPattern?.repeat(0...).createInstructions() ?? [.any]
		return [.split(first: reps.count + 2, second: 1)]
			+ reps
			+ [.jump(relative: -reps.count - 1)]
	}

	internal func prependSkip<C: BidirectionalCollection>(_ instructions: C)
		-> [Instruction<Input>] where C.Element == Instruction<Input> {
		var remainingInstructions = instructions[...]
		var chars = [Instruction<Input>]()[...]
		var nonIndexMovers = [Instruction<Input>]()[...]
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

		let search: (Input, Input.Index) -> Input.Index?
		let searchInstruction: Instruction<Input>

		switch chars.first {
		case nil:
			func isCheckIndex(_ inst: Instruction<Input>) -> Bool {
				if case .checkIndex = inst { return true } else { return false }
			}

			switch nonIndexMovers.popFirst(where: isCheckIndex(_:)) {
			case let .checkIndex(function):
				search = { input, index in
					input[index...].indices.first(where: { function(input, $0) })
						?? (function(input, input.endIndex) ? input.endIndex : nil)
				}
			default:
				return self.createInstructions() + instructions
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

		if let repeatedPattern = self.repeatedPattern {
			let skipInstructions = (repeatedPattern.repeat(0...).createInstructions() + [.match])[...]
			searchInstruction = .function { (input, thread) -> Bool in
				guard let end = search(input, thread.inputIndex) else { return false }
				guard let newThread = backtrackingVM(skipInstructions, input: String(input.prefix(upTo: end)),
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
			if self.repeatedPattern != nil {
				$0 += .cancelLastSplit
			}
		}
	}
}

extension Skip where Repeated == AnyPattern {
	public init() {
		self.description = "Skip()"
		self.repeatedPattern = nil
	}
}

public struct Capture<Wrapped: TextPattern>: TextPattern {
	public var description: String = "CAPTURE" // TODO: proper description
	public let name: String?
	public let patterns: Wrapped?
	/* TODO:
	 public var regex: String {
	 	let capturedRegex = patterns.map { ($0 as! RegexConvertible).regex }.joined()
	 	return name.map { "(?<\($0)>\(capturedRegex))" } ?? "(\(capturedRegex))"
	 }
	 */
	public init(name: String? = nil, _ patterns: Wrapped) {
		self.patterns = patterns
		self.name = name
	}

	public func createInstructions() -> [Instruction<Input>] {
		return [.captureStart(name: name)] + (patterns?.createInstructions() ?? []) + [.captureEnd]
	}

	public struct Start: TextPattern, RegexConvertible {
		public var description: String { return "[" }
		public var regex = "("
		public let name: String?

		public init(name: String? = nil) {
			self.name = name
		}

		public func createInstructions() -> [Instruction<Input>] {
			return [.captureStart(name: name)]
		}
	}

	public struct End: TextPattern, RegexConvertible {
		public var description: String { return "]" }
		public var regex = ")"

		public init() {}

		public func createInstructions() -> [Instruction<Input>] {
			return [.captureEnd]
		}
	}
}

extension Capture where Wrapped == AnyPattern {
	public init(name: String? = nil) {
		self.patterns = nil
		self.name = name
	}
}

public struct Parser<Input: BidirectionalCollection> where Input.Element: Equatable {
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

	let matcher: VMBacktrackEngine<Input>

	public init<P: TextPattern>(_ pattern: P) throws where P.Input == Input {
		self.matcher = try VMBacktrackEngine(pattern)
	}

	public func ranges(in input: Input, from startindex: Input.Index? = nil)
		-> AnySequence<Range<Input.Index>> {
		return AnySequence(matches(in: input, from: startindex).lazy.map(\.range))
	}

	public struct Match {
		public let fullRange: Range<Input.Index>
		public let captures: [(name: String?, range: Range<Input.Index>)]

		init(fullRange: Range<Input.Index>, captures: [(name: String?, range: Range<Input.Index>)]) {
			self.fullRange = fullRange
			self.captures = captures
		}

		public var range: Range<Input.Index> {
			captures.isEmpty ? fullRange : captures.first!.range.lowerBound ..< captures.last!.range.upperBound
		}

		public func description(using input: Input) -> String {
			return """
			fullRange: \(input[fullRange])
			captures: \(captures.map { "\($0.name ?? "")    \(input[$0.range])" })

			"""
		}

		public subscript(one name: String) -> Range<Input.Index>? {
			return captures.first(where: { $0.name == name })?.range
		}

		public subscript(multiple name: String) -> [Range<Input.Index>] {
			return captures.filter { $0.name == name }.map(\.range)
		}

		public var names: Set<String> { Set(captures.compactMap(\.name)) }
	}

	internal func match(in input: Input, at startindex: Input.Index) -> Match? {
		return matcher.match(in: input, at: startindex)
	}

	internal func match(in input: Input, from startIndex: Input.Index) -> Match? {
		return matcher.match(in: input, from: startIndex)
	}

	public func matches(in input: Input, from startindex: Input.Index? = nil)
		-> UnfoldSequence<Match, Input.Index> {
		var previousRange: Range<Input.Index>?
		return sequence(state: startindex ?? input.startIndex, next: { (index: inout Input.Index) in
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
