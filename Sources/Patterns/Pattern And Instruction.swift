//
//  Pattern And Instruction.swift
//
//
//  Created by Kåre Morstøl on 06/06/2020.
//

public protocol Pattern: CustomStringConvertible {
	typealias Input = String
	typealias ParsedRange = Range<Input.Index>
	typealias Instructions = ContiguousArray<Instruction<Input>>

	func createInstructions(_ instructions: inout Instructions) throws
	func createInstructions() throws -> Instructions
}

extension Pattern {
	public func createInstructions() throws -> Instructions {
		var instructions = Instructions()
		try self.createInstructions(&instructions)
		return instructions
	}
}

/// The instructions used by patterns in `createInstructions`.
/// Unless otherwise noted, each instruction moves on to the next instruction after it has finished.
public enum Instruction<Input: BidirectionalCollection> where Input.Element: Equatable {
	public typealias Distance = Int

	/// Succeeds if the current element equals this element. Advances index to the next element.
	case elementEquals(Input.Element)
	/// Succeeds if the closure returns true when passed the current element. Advances index to the next element.
	case checkElement((Input.Element) -> Bool)
	/// Succeeds if the closure returns true when passed the current index.
	case checkIndex((Input, Input.Index) -> Bool)
	/// Moves the input index by `offset`.
	case moveIndex(offset: Distance)

	case function((Input, inout VMBacktrackEngine<Input>.Thread) -> Bool) // TODO: remove

	/// Stores the current index as the beginning of capture `name`
	case captureStart(name: String?)
	/// Stores the current index as the end of the most recently started capture.
	case captureEnd
	/// Continues with the instruction at `offset` relative to this instruction.
	case jump(offset: Distance)
	/// Stores a snapshot of the current state. If there is a future failure the snapshot will be restored
	/// and the instruction at `offset` (relative to this instruction) will be called.
	case choice(offset: Distance, atIndexOffset: Int) // TODO: remove atIndexOffset
	/// Discards the state saved by previous `.choice`, because the instructions since then have completed
	/// successfully and the alternative instructions at the previous `.choice` are no longer needed.
	case commit
	/// Will be replaced by .call in preprocessing. Is never executed.
	case openCall(name: String)
	/// Goes to the sub-expression at `offset` relative to this instruction.
	case call(offset: Distance)
	/// Returns from this subexpression to where it was called from.
	case `return`
	/// Signals a failure.
	case fail
	/// A match has been successfully completed!
	///
	/// Will not continue with further instructions.
	case match

	/// Succeeds anywhere except at the end of the input.
	static var any: Self { Self.checkElement { _ in true } } // TODO: make its own instruction

	static func choice(offset: Int) -> Instruction {
		.choice(offset: offset, atIndexOffset: 0)
	}

	static func search(_ f: @escaping (Input, Input.Index) -> Input.Index?) -> Self {
		Self.function { (input: Input, thread: inout VMBacktrackEngine<Input>.Thread) -> Bool in
			guard let index = f(input, thread.inputIndex) else { return false }
			thread.inputIndex = index
			thread.instructionIndex += 1
			return true
		}
	}

	/// The offset by which this instruction will move the input index.
	var movesIndexBy: Int? {
		switch self {
		case .checkIndex, .captureStart, .captureEnd, .commit, .match:
			return 0
		case .elementEquals, .checkElement:
			return 1
		case let .moveIndex(offset):
			return offset
		case .function, .choice, .jump, .openCall, .call, .return, .fail:
			return nil
		}
	}
}

public extension Sequence where Element == Instruction<Pattern.Input> {
	/// The offset by which these instructions will move the input index.
	var movesIndexBy: Int? {
		lazy .map { $0.movesIndexBy }.reduceIfNoNils(into: 0) { result, offset in result += offset }
	}
}
