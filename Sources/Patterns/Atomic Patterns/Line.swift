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
extension String.UTF8View.Element: CharacterLike {
	@inlinable
	public var isNewline: Bool {
		// “\n” (U+000A): LINE FEED (LF), U+000B: LINE TABULATION (VT), U+000C: FORM FEED (FF), “\r” (U+000D): CARRIAGE RETURN (CR)
		(10 ... 13).contains(self)
	}
}

// U+0085: NEXT LINE (NEL), U+2028: LINE SEPARATOR, U+2029: PARAGRAPH SEPARATOR
@usableFromInline
let newlines = Set([0x000A as UInt16, 0x000B, 0x000C, 0x000D, 0x0085, 0x2028, 0x2029].map { Unicode.Scalar($0)! })

extension String.UnicodeScalarView.Element: CharacterLike {
	@inlinable
	public var isNewline: Bool {
		newlines.contains(self)
	}
}

extension String.UTF16View.Element: CharacterLike {
	@inlinable
	public var isNewline: Bool {
		Unicode.Scalar(self).map(newlines.contains(_:)) ?? false
	}
}

/// Matches one line, not including newline characters.
public struct Line<Input: BidirectionalCollection>: Pattern
	where Input.Element: CharacterLike, Input.Index == String.Index {
	public init() {}

	public var description: String { "Line()" }

	@inlinable
	public func createInstructions(_ instructions: inout ContiguousArray<Instruction<Input>>) throws {
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
