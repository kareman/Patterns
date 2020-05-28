//
//  Line.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public struct Line: Pattern {
	public let description: String = "line"

	public let pattern: Pattern
	public static let start = Start()
	public static let end = End()

	public init() {
		pattern = Start() • Skip() • End()
	}

	public func createInstructions(_ instructions: inout Instructions) {
		pattern.createInstructions(&instructions)
	}

	public struct Start: Pattern {
		public init() {}

		public var description: String { "line.start" }

		public func parse(_ input: Input, at index: Input.Index) -> Bool {
			index == input.startIndex || input[input.index(before: index)].isNewline
		}

		public func createInstructions(_ instructions: inout Instructions) {
			instructions.append(.checkIndex(self.parse(_:at:)))
		}
	}

	public struct End: Pattern {
		public init() {}

		public var description: String { "line.end" }

		public func parse(_ input: Input, at index: Input.Index) -> Bool {
			index == input.endIndex || input[index].isNewline
		}

		public func createInstructions(_ instructions: inout Instructions) {
			instructions.append(.checkIndex(self.parse(_:at:)))
		}
	}
}
