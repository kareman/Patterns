//
//  VMBacktrack.swift
//
//
//  Created by Kåre Morstøl on 18/04/2020.
//

public protocol TextPattern: CustomStringConvertible {
	typealias Input = Substring
	func createInstructions() -> [Instruction]
}

class VMBacktrackEngine: Matcher {
	let instructionsFrom: Array<Instruction>.SubSequence

	required init(_ pattern: TextPattern) throws {
		struct Match: TextPattern {
			let description = "match"
			func createInstructions() -> [Instruction] { [.match] }
		}
		instructionsFrom = prependSkip(skip: Skip(), (Capture(pattern) • Match()).createInstructions())[...]
	}

	func match(in input: TextPattern.Input, at startindex: TextPattern.Input.Index) -> Parser.Match? {
		// TODO: make more efficient.
		return backtrackingVM(instructionsFrom, input: input, startIndex: startindex).flatMap { $0.fullRange.lowerBound == startindex ? $0 : nil }
	}

	func match(in input: TextPattern.Input, from startIndex: TextPattern.Input.Index) -> Parser.Match? {
		return backtrackingVM(instructionsFrom, input: input, startIndex: startIndex)
	}
}

extension Parser.Match {
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

public struct Thread {
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
	case checkIndex((TextPattern.Input, TextPattern.Input.Index) -> Bool)
	case moveIndex(relative: Int)
	case function((TextPattern.Input, inout Thread) -> Bool)
	case captureStart(name: String?)
	case captureEnd
	case jump(relative: Int)
	case split(first: Int, second: Int, atIndex: Int)
	case cancelLastSplit
	case match

	static let any = Self.checkCharacter { _ in true }
	static func search(_ f: @escaping (TextPattern.Input, TextPattern.Input.Index) -> TextPattern.Input.Index?) -> Instruction {
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

func backtrackingVM(_ instructions: Array<Instruction>.SubSequence, input: TextPattern.Input, startIndex: TextPattern.Input.Index? = nil) -> Parser.Match? {
	let thread = Thread(instructionIndex: instructions.startIndex, inputIndex: startIndex ?? input.startIndex)
	return backtrackingVM(instructions, input: input, thread: thread)
		.map { Parser.Match($0, instructions: instructions) }
}

func backtrackingVM(_ instructions: Array<Instruction>.SubSequence, input: TextPattern.Input, thread: Thread) -> Thread? {
	var currentThreads = ContiguousArray<Thread>()[...]

	currentThreads.append(thread)
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
				currentThreads.append(newThread)
			case .cancelLastSplit:
				_ = currentThreads.popLast()
				thread.instructionIndex += 1
			case .match:
				return thread
			}
		}
	}

	return nil
}
