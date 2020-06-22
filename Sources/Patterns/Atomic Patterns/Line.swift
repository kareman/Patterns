//
//  Line.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

/// Matches one line, not including newline characters.
public struct Line: Pattern {
	public init() {}

	public var description: String { "Line()" }

	public static let start = Start()
	public static let end = End()

	@inlinable
	public func createInstructions(_ instructions: inout Instructions) throws {
		try (Start() • Skip() • End()).createInstructions(&instructions)
	}

	/// Matches the start of a line, including the start of input.
	public struct Start: Pattern {
		public init() {}

		public var description: String { "Line.start" }

		@inlinable
		func parse(_ input: Input, at index: Input.Index) -> Bool {
			(index == input.startIndex) || input[input.index(before: index)].isNewline
		}

		@inlinable
		public func createInstructions(_ instructions: inout Instructions) {
			instructions.append(.checkIndex(self.parse(_:at:)))
		}
	}

	/// Matches the end of a line, including the end of input.
	public struct End: Pattern {
		public init() {}

		public var description: String { "Line.end" }

		@inlinable
		func parse(_ input: Input, at index: Input.Index) -> Bool {
			index == input.endIndex || input[index].isNewline
		}

		@inlinable
		public func createInstructions(_ instructions: inout Instructions) {
			instructions.append(.checkIndex(self.parse(_:at:)))
		}
	}
}
