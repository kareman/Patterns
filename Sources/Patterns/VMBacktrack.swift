//
//  VMBacktrack.swift
//
//
//  Created by Kåre Morstøl on 18/04/2020.
//

// TODO: struct?
class VMBacktrackEngine<Input: BidirectionalCollection> where Input.Element: Equatable {
	let instructionsFrom: Array<Instruction<Input>>.SubSequence

	required init<P: Pattern>(_ pattern: P) throws where Input == P.Input {
		if pattern is Grammar {
			instructionsFrom = (Capture(pattern).createInstructions() + [Instruction<Input>.match])[...]
		} else {
			instructionsFrom = Skip().prependSkip(Capture(pattern).createInstructions() + [Instruction<Input>.match])[...]
		}
	}

	/*	init(_ pattern: Grammar) throws {
	 	instructionsFrom = (Capture(pattern).createInstructions() + [Instruction<Input>.match])[...]
	 }
	 */
	@usableFromInline
	func match(in input: Input, at startindex: Input.Index) -> Parser<Input>.Match? {
		// TODO: make more efficient.
		return VMBacktrackEngine<Input>.backtrackingVM(instructionsFrom, input: input, startIndex: startindex).flatMap { $0.fullRange.lowerBound == startindex ? $0 : nil }
	}

	@usableFromInline
	func match(in input: Input, from startIndex: Input.Index) -> Parser<Input>.Match? {
		return VMBacktrackEngine<Input>.backtrackingVM(instructionsFrom, input: input, startIndex: startIndex)
	}
}

extension Parser.Match {
	init(_ thread: Thread<Input>, instructions: Array<Instruction<Input>>.SubSequence) {
		var captures = [(name: String?, range: Range<Input.Index>)]()
		captures.reserveCapacity(thread.captures.count / 2)
		var captureBeginnings = [(name: String?, start: Input.Index)]()
		captureBeginnings.reserveCapacity(captures.capacity)
		for capture in thread.captures {
			switch instructions[capture.instruction] {
			case let .captureStart(name):
				captureBeginnings.append((name, capture.index))
			case .captureEnd:
				let beginning = captureBeginnings.removeLast()
				captures.append((name: beginning.name, range: beginning.start ..< capture.index))
			default:
				fatalError("Captured wrong instructions")
			}
		}
		assert(captureBeginnings.isEmpty)
		self.fullRange = captures.removeLast().range
		self.captures = captures
	}
}

// TODO: private
public struct Thread<Input: BidirectionalCollection> where Input.Element: Equatable {
	var instructionIndex: Array<Instruction<Input>>.SubSequence.Index
	var inputIndex: Input.Index
	var captures: ContiguousArray<(index: Input.Index, instruction: Array<Instruction<Input>>.Index)>

	init(startAt instructionIndex: Int, withDataFrom other: Thread) {
		self.instructionIndex = instructionIndex
		self.inputIndex = other.inputIndex
		self.captures = other.captures
	}

	init(instructionIndex: Array<Instruction<Input>>.SubSequence.Index, inputIndex: Input.Index) {
		self.instructionIndex = instructionIndex
		self.inputIndex = inputIndex
		self.captures = []
	}
}

public enum Instruction<Input: BidirectionalCollection> where Input.Element: Equatable {
	public typealias Distance = Int
	case literal(Input.Element)
	case checkCharacter((Input.Element) -> Bool)
	case checkIndex((Input, Input.Index) -> Bool)
	case moveIndex(relative: Distance)
	case function((Input, inout Thread<Input>) -> Bool)
	case captureStart(name: String?)
	case captureEnd
	case jump(relative: Distance)
	case split(first: Distance, second: Distance, atIndex: Int)
	case cancelLastSplit
	case openCall(name: String) // will be replaced by .call in preprocessing.
	case call(address: Int)
	case `return`
	case fail
	case match

	static var any: Instruction { Self.checkCharacter { _ in true } }
	static func search(_ f: @escaping (Input, Input.Index) -> Input.Index?) -> Instruction {
		.function { (input, thread) -> Bool in
			guard let index = f(input, thread.inputIndex) else { return false }
			thread.inputIndex = index
			thread.instructionIndex += 1
			return true
		}
	}

	static func split(first: Int, second: Int) -> Instruction {
		.split(first: first, second: second, atIndex: 0)
	}
}

extension VMBacktrackEngine {
	@usableFromInline
	static func backtrackingVM(_ instructions: Array<Instruction<Input>>.SubSequence, input: Input, startIndex: Input.Index? = nil) -> Parser<Input>.Match? {
		let thread = Thread<Input>(instructionIndex: instructions.startIndex, inputIndex: startIndex ?? input.startIndex)
		return backtrackingVM(instructions, input: input, thread: thread)
			.map { Parser.Match($0, instructions: instructions) }
	}

	enum StackEntry {
		case returnAddress(Int)
		case thread(Thread<Input>)

		var returnAddress: Int? {
			switch self {
			case let .returnAddress(return: address):
				return address
			default:
				return nil
			}
		}

		var thread: Thread<Input>? {
			switch self {
			case let .thread(thread):
				return thread
			default:
				return nil
			}
		}
	}

	@usableFromInline
	static func backtrackingVM(_ instructions: Array<Instruction<Input>>.SubSequence, input: Input, thread: Thread<Input>) -> Thread<Input>? {
		var stack = ContiguousArray<StackEntry>()[...]

		stack.append(.thread(thread))
		while var thread = stack.popLast()?.thread
			.onNil(fatalError("Stack unexpectedly contains .returnAddress after fail")) {
				
			defer { // Fail, when `break loop` is called.
				stack = stack.dropLast(while: { $0.returnAddress != nil })
			}

			loop: while true {
				guard thread.instructionIndex < instructions.endIndex else { fatalError("Tried reaching instruction past end.") }
				switch instructions[thread.instructionIndex] {
				case let .literal(char):
					guard thread.inputIndex != input.endIndex, input[thread.inputIndex] == char else { break loop }
					input.formIndex(after: &thread.inputIndex)
					thread.instructionIndex += 1
				case let .checkCharacter(test):
					guard thread.inputIndex != input.endIndex, test(input[thread.inputIndex]) else { break loop }
					input.formIndex(after: &thread.inputIndex)
					thread.instructionIndex += 1
				case let .checkIndex(test):
					guard test(input, thread.inputIndex) else { break loop }
					thread.instructionIndex += 1
				case let .moveIndex(relative: distance):
					guard input.formIndexSafely(&thread.inputIndex, offsetBy: distance) else { break loop }
					thread.instructionIndex += 1
				case let .function(function):
					guard function(input, &thread) else { break loop }
				case let .jump(relative: distance):
					thread.instructionIndex += distance
				case .captureStart(_), .captureEnd:
					thread.captures.append((index: thread.inputIndex, instruction: thread.instructionIndex))
					thread.instructionIndex += 1
				case let .split(first, second, atIndex):
					defer { thread.instructionIndex += first }
					var newThread = Thread(startAt: thread.instructionIndex + second, withDataFrom: thread)
					if atIndex != 0 {
						guard input.formIndexSafely(&newThread.inputIndex, offsetBy: atIndex) else { break }
					}
					stack.append(.thread(newThread))
				case .cancelLastSplit:
					let entry = stack.popLast()
					assert(entry.onNil(fatalError("Empty stack during .cancelLastSplit")).thread != nil ,
								 "Missing thread during .cancelLastSplit")
					thread.instructionIndex += 1
				case let .call(address):
					stack.append(.returnAddress(thread.instructionIndex + 1))
					thread.instructionIndex += address
				case .return:
					switch stack.popLast() {
					case let .returnAddress(address):
						thread.instructionIndex = address
					case .thread:
						fatalError("Unexpected uncommited thread in stack.")
					case nil:
						fatalError("Missing return address in call.")
					}
				case .fail:
					break loop
				case .match:
					return thread
				case .openCall:
					fatalError("`.openCall` should be removed by Grammar.")
				}
			}
		}

		return nil
	}
}
