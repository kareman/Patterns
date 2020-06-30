//
//  Regex.swift
//
//
//  Created by Kåre Morstøl on 18/04/2020.
//

import Foundation

/// A pattern that can be converted to regex.
public protocol RegexConvertible: Pattern {
	/// The equivalent regex for this pattern.
	var regex: String { get }
}

// For `OneOf` to be convertible the regex has to be provided manually when it is created.

extension Literal: RegexConvertible {
	public var regex: String { NSRegularExpression.escapedPattern(for: String(elements)) }
}

extension Line: RegexConvertible {
	public var regex: String { "^.*$" }
}

extension Line.Start: RegexConvertible {
	public var regex: String { "^" }
}

extension Line.End: RegexConvertible {
	public var regex: String { "$" }
}

extension Word.Boundary: RegexConvertible {
	public var regex: String { #"\b"# }
}

extension Capture: RegexConvertible where Wrapped: RegexConvertible {
	public var regex: String {
		let capturedRegex = wrapped.regex
		return name.map { "(?<\($0)>\(capturedRegex))" } ?? "(\(capturedRegex))"
	}
}

extension Concat: RegexConvertible where First: RegexConvertible, Second: RegexConvertible {
	public var regex: String { first.regex + second.regex }
}

extension OrPattern: RegexConvertible where First: RegexConvertible, Second: RegexConvertible {
	public var regex: String { first.regex + "|" + second.regex }
}

extension RepeatPattern: RegexConvertible where Wrapped: RegexConvertible {
	public var regex: String {
		"(?:\(wrapped.regex){\(min),\(max.map(String.init(describing:)) ?? "")}"
	}
}

extension Skip: RegexConvertible {
	public var regex: String { ".*?" }
}

extension NoPattern: RegexConvertible {
	public var regex: String { "" }
}
