//
//  Regex.swift
//
//
//  Created by Kåre Morstøl on 18/04/2020.
//

import Foundation

public protocol RegexConvertible {
	var regex: String { get }
}

extension Literal: RegexConvertible {
	public var regex: String { NSRegularExpression.escapedPattern(for: String(substring)) }
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

extension CaptureStart: RegexConvertible {
	public var regex: String { "(" }
}

extension CaptureEnd: RegexConvertible {
	public var regex: String { ")" }
}

extension Concat: RegexConvertible where Left: RegexConvertible, Right: RegexConvertible {
	public var regex: String { left.regex + right.regex }
}

extension OrPattern: RegexConvertible where First: RegexConvertible, Second: RegexConvertible {
	public var regex: String { first.regex + "|" + second.regex }
}

extension RepeatPattern: RegexConvertible where Repeated: RegexConvertible {
	public var regex: String {
		"(?:\(repeatedPattern.regex){\(min),\(max.map(String.init(describing:)) ?? "")}"
	}
}

extension Skip: RegexConvertible {
	public var regex: String { ".*?" }
}
