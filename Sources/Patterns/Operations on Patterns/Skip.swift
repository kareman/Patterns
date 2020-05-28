//
//  Skip.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public struct Skip<Repeated: Pattern>: Pattern {
	public let repeatedPattern: Repeated?
	public let description: String

	public init(_ repeatedPattern: Repeated) {
		self.repeatedPattern = repeatedPattern
		self.description = "Skip(\(repeatedPattern))"
	}

	public func createInstructions(_ instructions: inout Instructions) {
		let reps = repeatedPattern?.repeat(0...).createInstructions() ?? [.any]
		instructions.append(.split(first: reps.count + 2, second: 1))
		instructions.append(contentsOf: reps)
		instructions.append(.jump(offset: -reps.count - 1))
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
					nonIndexMovers.append(.moveIndex(offset: moveBy))
					lastMoveTo = chars.count
				}
				nonIndexMovers.append(inst)
			case .jump, .split, .match, .moveIndex, .function, .call, .return, .fail, .openCall:
				remainingInstructions = instructions[instructions.index(before: remainingInstructions.startIndex)...]
				break loop
			}
		}
		if chars.count - lastMoveTo != 0 {
			nonIndexMovers.append(.moveIndex(offset: chars.count - lastMoveTo))
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
				return self.createInstructions().array() + instructions
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
				guard let newThread = VMBacktrackEngine<Input>.backtrackingVM(skipInstructions, input: String(input.prefix(upTo: end)),
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
			$0 += .moveIndex(offset: -chars.count)
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

extension Skip where Repeated == Literal {
	public init(_ repeatedPattern: Literal) {
		self.repeatedPattern = repeatedPattern
		self.description = "Skip(\(repeatedPattern))"
	}
}
