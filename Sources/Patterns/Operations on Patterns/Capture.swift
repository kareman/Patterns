//
//  Capture.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public struct Capture<Wrapped: TextPattern>: TextPattern {
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

	public struct Start: TextPattern, RegexConvertible {
		public var description: String { return "[" }
		public var regex = "("
		public let name: String?

		public init(name: String? = nil) {
			self.name = name
		}

		public func createInstructions() -> [Instruction<Input>] {
			return [.captureStart(name: name)]
		}
	}

	public struct End: TextPattern, RegexConvertible {
		public var description: String { return "]" }
		public var regex = ")"

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

extension Capture: RegexConvertible where Wrapped: RegexConvertible {
	public var regex: String {
		let capturedRegex = wrapped?.regex ?? ""
		return name.map { "(?<\($0)>\(capturedRegex))" } ?? "(\(capturedRegex))"
	}
}
