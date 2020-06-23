//
//  Capture.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

/// Captures the current position as a range.
///
/// It can be retrieved in `Parser.Match.captures` or used for decoding into Decodables.
public struct Capture<Wrapped: Pattern>: Pattern {
	public var description: String {
		let result: String
		switch (name, wrapped) {
		case (nil, is NoPattern):
			result = ""
		case let (name?, is NoPattern):
			result = "name: \(name)"
		case let (name?, wrapped):
			result = "name: \(name), \(wrapped)"
		case let (nil, wrapped):
			result = wrapped.description
		}
		return "Capture(\(result))"
	}

	public let name: String?
	public let wrapped: Wrapped

	/// Captures the position of `wrapped` as a range.
	/// - Parameters:
	///   - name: optional name
	@inlinable
	public init(name: String? = nil, _ wrapped: Wrapped) {
		self.name = name
		self.wrapped = wrapped
	}

	@inlinable
	public func createInstructions(_ instructions: inout Instructions) throws {
		instructions.append(.captureStart(name: name))
		try wrapped.createInstructions(&instructions)
		instructions.append(.captureEnd)
	}
}

extension Capture where Wrapped == NoPattern {
	/// Captures the current input position as an empty range.
	/// - Parameter name: optional name
	@inlinable
	public init(name: String? = nil) {
		self.wrapped = NoPattern()
		self.name = name
	}
}

extension Capture where Wrapped == Literal {
	/// Captures the position of `wrapped` as a range.
	/// - Parameter name: optional name
	@inlinable
	public init(name: String? = nil, _ wrapped: Literal) {
		self.wrapped = wrapped
		self.name = name
	}
}

/// A pattern that does absolutely nothing.
public struct NoPattern: Pattern {
	public var description: String { "" }

	public init() {}

	public func createInstructions(_ instructions: inout Instructions) throws {}
}
