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

public class VMBacktrackEngine: Matcher {
	let series: [VMPattern]

	required init(_ series: [VMPattern]) throws {
		self.series = series
	}

	func match(in input: Patterns.Input, at startindex: Patterns.Input.Index) -> Patterns.Match? {
		fatalError()
	}

	func match(in input: Patterns.Input, from startIndex: Patterns.Input.Index) -> Patterns.Match? {
		fatalError()
	}
}

extension Patterns.Match {
	init(_ thread: Thread, instructions: [Instruction]) {
		var captures = [(name: String?, range: ParsedRange)]()
		captures.reserveCapacity(thread.captures.count / 2)
		var captureBeginnings = [(name: String?, start: String.Index)]()
		captureBeginnings.reserveCapacity(captures.capacity)
		for capture in thread.captures {
			switch instructions[capture.instruction] {
			case let .captureStart(name):
				captureBeginnings.append((name, capture.index))
			case .captureEnd:
				let beginning = captureBeginnings.popLast()!
				captures.append((name: beginning.name, range: beginning.start ..< capture.index))
			default:
				fatalError("Captured wrong instructions")
			}
		}
		assert(captureBeginnings.isEmpty)
		self.fullRange = captures.removeFirst().range
		self.captures = captures
	}
}

struct Thread {
	var instructionIndex: Array<Instruction>.Index
	var inputIndex: String.Index
	var captures: ContiguousArray<(index: String.Index, instruction: Array<Instruction>.Index)>

	public init(startAt instructionIndex: Int, withDataFrom other: Thread) {
		self.instructionIndex = instructionIndex
		self.inputIndex = other.inputIndex
		self.captures = other.captures
	}

	init(instructionIndex: Array<Instruction>.Index, inputIndex: String.Index) {
		self.instructionIndex = instructionIndex
		self.inputIndex = inputIndex
		self.captures = []
	}
}

public enum Instruction {
	case literal(Character)
	case checkCharacter((Character) -> Bool)
	case match
	case captureStart(name: String?)
	case captureEnd
	case jump(relative: Int)
	case split(first: Int, second: Int)

	static let any = Self.checkCharacter { _ in true }
}

func pike<S: StringProtocol>(_ instructions: [Instruction], input: S, startIndex: String.Index? = nil) -> Patterns.Match? {
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
			case let .jump(relative: distance):
				thread.instructionIndex += distance
			case .captureStart(_), .captureEnd:
				thread.captures.append((index: thread.inputIndex, instruction: thread.instructionIndex))
				thread.instructionIndex += 1
			case let .split(first: first, second: second):
				currentThreads.append(Thread(startAt: thread.instructionIndex + second, withDataFrom: thread))
				thread.instructionIndex += first
			case .match:
				return Patterns.Match(thread, instructions: instructions)
			}
		}
	}

	return nil
}

extension Patterns {
	func parse(_ input: String) -> Patterns.Match? {
		let instructions = [Instruction.captureStart(name: nil)] + self.createInstructions() + [.captureEnd, .match]
		return pike(instructions, input: input)
	}
}
