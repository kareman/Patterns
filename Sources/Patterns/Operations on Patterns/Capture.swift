//
//  Capture.swift
//
//
//  Created by Kåre Morstøl on 25/05/2020.
//

public struct CaptureStart: Pattern {
	public var description: String { "CaptureStart(\(name.map { "name: \($0)" } ?? "")" }
	public let name: String?

	public init(name: String? = nil) {
		self.name = name
	}

	public func createInstructions(_ instructions: inout Instructions) {
		instructions.append(.captureStart(name: name))
	}
}

public struct CaptureEnd: Pattern {
	public var description: String { "CaptureEnd()" }

	public init() {}

	public func createInstructions(_ instructions: inout Instructions) {
		instructions.append(.captureEnd)
	}
}

/// Captures the current position in the input as an empty range.
/// - returns: `CaptureStart(name: name) • CaptureEnd()`
@inlinable
public func Capture(name: String? = nil) -> Concat<CaptureStart, CaptureEnd> {
	CaptureStart(name: name) • CaptureEnd()
}

/// Captures the position in the input of `wrapped` as a range.
/// - returns: `CaptureStart(name: name) • wrapped • CaptureEnd()`
@inlinable
public func Capture<P: Pattern>(name: String? = nil, _ wrapped: P) -> Concat<CaptureStart, Concat<P, CaptureEnd>> {
	CaptureStart(name: name) • wrapped • CaptureEnd()
}

@inlinable
public func Capture(name: String? = nil, _ wrapped: Literal) -> Concat<CaptureStart, Concat<Literal, CaptureEnd>> {
	CaptureStart(name: name) • wrapped • CaptureEnd()
}

/**
 'flattens' the types to make it easier for `Skip` to see what comes after it.
 By converting `before • Capture(wrapped) • after` into
 `before • CaptureStart() • wrapped • CaptureEnd() • after` instead of
 `before • (CaptureStart() • wrapped • CaptureEnd()) • after`.
 */
@inlinable
public func • <Wrapped: Pattern, After: Pattern>(lhs: Concat<CaptureStart, Concat<Wrapped, CaptureEnd>>, rhs: After)
	-> Concat<CaptureStart, Concat<Wrapped, Concat<CaptureEnd, After>>> {
	lhs.left • lhs.right.left • lhs.right.right • rhs
}

@inlinable
public func • <Wrapped: Pattern>(lhs: Concat<CaptureStart, Concat<Wrapped, CaptureEnd>>, rhs: Literal)
	-> Concat<CaptureStart, Concat<Wrapped, Concat<CaptureEnd, Literal>>> {
	lhs.left • lhs.right.left • lhs.right.right • rhs
}
