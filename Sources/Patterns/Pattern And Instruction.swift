//
//  Pattern And Instruction.swift
//
//
//  Created by Kåre Morstøl on 06/06/2020.
//

public protocol Pattern: CustomStringConvertible {
	typealias Input = String
	typealias ParsedRange = Range<Input.Index>
	typealias Instructions = ContiguousArray<Instruction<Input>> // TODO: use almost everywhere

	func createInstructions(_ instructions: inout Instructions)
	func createInstructions() -> Instructions
}

extension Pattern {
	public func createInstructions() -> Instructions {
		var instructions = Instructions()
		self.createInstructions(&instructions)
		return instructions
	}
}

public enum Instruction<Input: BidirectionalCollection> where Input.Element: Equatable {
	public typealias Distance = Int
	case literal(Input.Element)
	case checkCharacter((Input.Element) -> Bool)
	case checkIndex((Input, Input.Index) -> Bool)
	case moveIndex(offset: Distance)
	case function((Input, inout VMBacktrackEngine<Input>.Thread) -> Bool) // TODO: remove
	case captureStart(name: String?)
	case captureEnd
	case jump(offset: Distance)
	case split(first: Distance, second: Distance, atIndex: Int)
	case cancelLastSplit
	case openCall(name: String) // will be replaced by .call in preprocessing.
	case call(offset: Int)
	case `return`
	case fail
	case match

	static var any: Self { Self.checkCharacter { _ in true } } // TODO: make its own instruction
	static func search(_ f: @escaping (Input, Input.Index) -> Input.Index?) -> Self {
		Self.function { (input: Input, thread: inout VMBacktrackEngine<Input>.Thread) -> Bool in
			guard let index = f(input, thread.inputIndex) else { return false }
			thread.inputIndex = index
			thread.instructionIndex += 1
			return true
		}
	}

	static func split(first: Int, second: Int) -> Instruction {
		.split(first: first, second: second, atIndex: 0)
	}

	var movesIndexBy: Int? {
		switch self {
		case .checkIndex, .captureStart, .captureEnd, .cancelLastSplit, .match:
			return 0
		case .literal, .checkCharacter:
			return 1
		case let .moveIndex(offset):
			return offset
		case .function, .split, .jump, .openCall, .call, .return, .fail:
			return nil
		}
	}
}

public extension Sequence where Element == Instruction<Pattern.Input> {
	var movesIndexBy: Int? {
		lazy .map { $0.movesIndexBy }.reduceIfNoNils(into: 0) { result, offset in result += offset }
	}
}
