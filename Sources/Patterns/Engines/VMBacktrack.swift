//
//  VMBacktrack.swift
//
//
//  Created by Kåre Morstøl on 18/04/2020.
//

public protocol VMPattern: CustomStringConvertible {
	typealias Input = Substring // TODO: remove
	func createInstructions() -> [Instruction]
}

class VMBacktrackEngine: Matcher {
	let instructionsFrom, instructionsAt: Array<Instruction>.SubSequence

	required init(_ series: [VMPattern]) throws {
		let skips = Skip().createInstructions()
		instructionsFrom = (skips + [.captureStart(name: nil)]
			+ series.flatMap { $0.createInstructions() }
			+ [.captureEnd, .match])[...]
		instructionsAt = instructionsFrom.dropFirst(skips.count)
	}

	func match(in input: Patterns.Input, at startindex: Patterns.Input.Index) -> Patterns.Match? {
		return pike(instructionsAt, input: input, startIndex: startindex)
	}

	func match(in input: Patterns.Input, from startIndex: Patterns.Input.Index) -> Patterns.Match? {
		return pike(instructionsFrom, input: input, startIndex: startIndex)
	}
}

extension Patterns.Match {
	init(_ thread: Thread, instructions: Array<Instruction>.SubSequence) {
		var captures = [(name: String?, range: ParsedRange)]()
		captures.reserveCapacity(thread.captures.count / 2)
		var captureBeginnings = [(name: String?, start: String.Index)]()
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

struct Thread {
	var instructionIndex: Array<Instruction>.SubSequence.Index
	var inputIndex: String.Index
	var captures: ContiguousArray<(index: String.Index, instruction: Array<Instruction>.Index)>

	init(startAt instructionIndex: Int, withDataFrom other: Thread) {
		self.instructionIndex = instructionIndex
		self.inputIndex = other.inputIndex
		self.captures = other.captures
	}

	init(instructionIndex: Array<Instruction>.SubSequence.Index, inputIndex: String.Index) {
		self.instructionIndex = instructionIndex
		self.inputIndex = inputIndex
		self.captures = []
	}
}

public enum Instruction {
	case literal(Character)
	case checkCharacter((Character) -> Bool)
	case checkIndex((Patterns.Input.Index, Patterns.Input) -> Bool)
	case captureStart(name: String?)
	case captureEnd
	case jump(relative: Int)
	case split(first: Int, second: Int)
	case cancelLastSplit
	case match

	static let any = Self.checkCharacter { _ in true }
}

func pike(_ instructions: Array<Instruction>.SubSequence, input: Patterns.Input, startIndex: Patterns.Input.Index? = nil) -> Patterns.Match? {
	let startIndex = startIndex ?? input.startIndex
	var currentThreads = ContiguousArray<Thread>()[...]

	currentThreads.append(Thread(instructionIndex: instructions.startIndex, inputIndex: startIndex))
	while var thread = currentThreads.popLast() {
		loop: while true {
			guard thread.instructionIndex < instructions.endIndex else { break loop }
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
				guard test(thread.inputIndex, input) else { break loop }
				thread.instructionIndex += 1
			case let .jump(relative: distance):
				thread.instructionIndex += distance
			case .captureStart(_), .captureEnd:
				thread.captures.append((index: thread.inputIndex, instruction: thread.instructionIndex))
				thread.instructionIndex += 1
			case let .split(first, second):
				currentThreads.append(Thread(startAt: thread.instructionIndex + second, withDataFrom: thread))
				thread.instructionIndex += first
			case .cancelLastSplit:
				_ = currentThreads.popLast()
				thread.instructionIndex += 1
			case .match:
				return Patterns.Match(thread, instructions: instructions)
			}
		}
	}

	return nil
}
