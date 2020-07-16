//
//  Line.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public protocol CharacterLike: Hashable {
	var isNewline: Bool { get }
}

extension Character: CharacterLike {}
extension Unicode.Scalar: CharacterLike {
	public var isNewline: Bool {
		self.isNewline
	}
}

/// Matches one line, not including newline characters.
public struct Line<Input: BidirectionalCollection>: Pattern
	where Input.Element: CharacterLike, Input.Index == String.Index {
	public init() {}

	public var description: String { "Line()" }

	@inlinable
	public func createInstructions(_ instructions: inout Self.Instructions) throws {
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
		public func createInstructions(_ instructions: inout Self.Instructions) {
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
		public func createInstructions(_ instructions: inout Self.Instructions) {
			instructions.append(.checkIndex(self.parse(_:at:)))
		}
	}
}

extension Line where Input == String {
	public static let start = Start()
	public static let end = End()
}
