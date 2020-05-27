//
//  Capture.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public struct Capture<Wrapped: Pattern>: Pattern {
	public var description: String = "CAPTURE" // TODO: proper description
	public let name: String?
	public let wrapped: Wrapped?

	public init(name: String? = nil, _ patterns: Wrapped) {
		self.wrapped = patterns
		self.name = name
	}

	public func createInstructions() -> [Instruction<Input>] {
		return [.captureStart(name: name)] + (wrapped?.createInstructions() ?? []) + [.captureEnd]
	}

	public struct Start: Pattern {
		public var description: String { return "[" }
		public let name: String?

		public init(name: String? = nil) {
			self.name = name
		}

		public func createInstructions() -> [Instruction<Input>] {
			return [.captureStart(name: name)]
		}
	}

	public struct End: Pattern {
		public var description: String { return "]" }

		public init() {}

		public func createInstructions() -> [Instruction<Input>] {
			return [.captureEnd]
		}
	}
}

extension Capture where Wrapped == AnyPattern {
	public init(name: String? = nil) {
		self.wrapped = nil
		self.name = name
	}
}

extension Capture where Wrapped == Literal {
	public init(name: String? = nil, _ patterns: Literal) {
		self.wrapped = patterns
		self.name = name
	}
}
