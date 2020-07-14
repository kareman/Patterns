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
	public typealias Input = Wrapped.Input
	public var description: String {
		let result: String
		switch (name, wrapped) {
		case (nil, is NoPattern<Input>):
			result = ""
		case let (name?, is NoPattern<Input>):
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
	public func createInstructions(_ instructions: inout Self.Instructions) throws {
		instructions.append(.captureStart(name: name))
		try wrapped.createInstructions(&instructions)
		instructions.append(.captureEnd)
	}
}

/*
 extension Capture {
 /// Captures the current input position as an empty range.
 /// - Parameter name: optional name
 @inlinable
 public init<Input>(name: String? = nil) where Wrapped == NoPattern<Input> {
 	self.wrapped = NoPattern<Input>()
 	self.name = name
 }
 }
 */
extension Capture {
	/// Captures the position of `wrapped` as a range.
	/// - Parameter name: optional name
	@inlinable
	public init<Input>(name: String? = nil, _ wrapped: Literal<Input>) where Wrapped == Literal<Input> {
		self.wrapped = wrapped
		self.name = name
	}
}

/// A pattern that does absolutely nothing.
public struct NoPattern<Input: BidirectionalCollection>: Pattern where Input.Element: Hashable {
	public var description: String { "" }

	@inlinable
	public init() {}

	@inlinable
	public func createInstructions(_ instructions: inout Self.Instructions) throws {}
}
