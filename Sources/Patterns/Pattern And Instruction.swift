//
//  Pattern And Instruction.swift
//
//
//  Created by Kåre Morstøl on 06/06/2020.
//

/// Something that can create Instructions for the Parser.
public protocol Pattern: CustomStringConvertible {
	typealias Input = String
	typealias ParsedRange = Range<Input.Index>
	typealias Instructions = ContiguousArray<Instruction<Input>>

	/// Appends Instructions for the Parser to `instructions`.
	@inlinable
	func createInstructions(_ instructions: inout Instructions) throws
	/// Returns Instructions for the Parser.
	@inlinable
	func createInstructions() throws -> Instructions
}

extension Pattern {
	/// Returns Instructions for the Parser.
	@inlinable
	public func createInstructions() throws -> Instructions {
		var instructions = Instructions()
		try self.createInstructions(&instructions)
		return instructions
	}
}

/// The instructions used by patterns in `createInstructions`.
///
/// Unless otherwise noted, each instruction moves on to the next instruction after it has finished.
public enum Instruction<Input: BidirectionalCollection> where Input.Element: Hashable {
	public typealias Distance = Int

	/// Succeeds if the current element equals this element. Advances index to the next element.
	case elementEquals(Input.Element)
	/// Succeeds if the closure returns true when passed the current element. Advances index to the next element.
	case checkElement((Input.Element) -> Bool)
	/// Succeeds if the closure returns true when passed the input and the input index + `atIndexOffset`.
	case checkIndex((Input, Input.Index) -> Bool, atIndexOffset: Int)

	/// Moves the input index by `offset`.
	case moveIndex(offset: Distance)
	/// Continues with the instruction at `offset` relative to this instruction.
	case jump(offset: Distance)

	/// Sets the input index to the output from the closure.
	/// If the output is nil, the instruction fails.
	case search((Input, Input.Index) -> Input.Index?)

	/// Stores (current input index - `atIndexOffset`) as the beginning of capture `name`
	case captureStart(name: String?, atIndexOffset: Int)
	/// Stores (current input index - `atIndexOffset`) as the end of the most recently started capture.
	case captureEnd(atIndexOffset: Int)

	/// Stores a snapshot of the current state, with input index set to (current + `atIndexOffset`).
	///
	/// If there is a future failure the snapshot will be restored
	/// and the instruction at `offset` (relative to this instruction) will be called.
	case choice(offset: Distance, atIndexOffset: Int)
	/// Signals the end of a choice. Doesn't do anything else.
	/// Used as a barrier across which instructions cannot be moved.
	case choiceEnd
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

	/// Will be replaced in preprocessing. Is never executed.
	case skip

	/// Succeeds anywhere except at the end of the input.
	@inlinable
	public static var any: Self { Self.checkElement { _ in true } } // TODO: make its own instruction

	/// Stores the current input index as the beginning of capture `name`
	@inlinable
	public static func captureStart(name: String?) -> Self {
		.captureStart(name: name, atIndexOffset: 0)
	}

	/// Stores the current input index as the end of the most recently started capture.
	@inlinable
	public static var captureEnd: Self {
		.captureEnd(atIndexOffset: 0)
	}

	/// Succeeds if the closure returns true when passed the input and the input index.
	@inlinable
	public static func checkIndex(_ test: @escaping (Input, Input.Index) -> Bool) -> Self {
		.checkIndex(test, atIndexOffset: 0)
	}

	/// Stores a snapshot of the current state.
	///
	/// If there is a future failure the snapshot will be restored
	/// and the instruction at `offset` (relative to this instruction) will be called.
	@inlinable
	public static func choice(offset: Int) -> Instruction {
		.choice(offset: offset, atIndexOffset: 0)
	}

	/// The offset by which this instruction will move the input index.
	@usableFromInline
	var movesIndexBy: Int? {
		switch self {
		case .checkIndex, .captureStart, .captureEnd, .commit, .match, .choiceEnd:
			return 0
		case .elementEquals, .checkElement:
			return 1
		case let .moveIndex(offset):
			return offset
		case .search, .choice, .jump, .openCall, .call, .return, .fail, .skip:
			return nil
		}
	}

	/// Returns false only if instruction has no effect.
	@usableFromInline
	var doesNotDoAnything: Bool {
		switch self {
		case .choiceEnd, .jump(+1):
			return true
		default:
			return false
		}
	}
}

extension Sequence where Element == Instruction<Pattern.Input> {
	/// The offset by which these instructions will move the input index.
	@inlinable
	var movesIndexBy: Int? {
		lazy .map { $0.movesIndexBy }.reduceIfNoNils(into: 0) { result, offset in result += offset }
	}
}
