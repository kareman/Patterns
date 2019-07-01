//
//  Group.swift
//  TextPicker
//
//  Created by Kåre Morstøl on 23/04/2019.
//

public struct Group<Element> {
	public let contains: (Element) -> Bool

	public init(contains: @escaping (Element) -> Bool) {
		self.contains = contains
	}

	func contains<S: Sequence>(contentsOf s: S) -> Bool where S.Element == Element {
		return s.allSatisfy(contains)
	}
}

public extension Group {
	func union(_ other: Group) -> Group {
		return Group {
			self.contains($0) || other.contains($0)
		}
	}

	static func || (a: Group, b: Group) -> Group {
		return a.union(b)
	}

	func intersection(_ other: Group) -> Group {
		return Group {
			self.contains($0) && other.contains($0)
		}
	}

	func inverted() -> Group<Element> {
		return Group {
			!self.contains($0)
		}
	}
}

public extension Group where Element: Hashable {
	init(contentsOf set: Set<Element>) {
		contains = set.contains
	}

	init<S>(contentsOf sequence: S) where S: Sequence, Element == S.Element {
		self.init(contentsOf: Set(sequence))
	}
}

/*
 import Foundation

 public extension Group where Element == Character {
 init(description: String, characterSet: CharacterSet) {
 	self.description = description
 	regex = "[\(characterSet.map(String.init(describing:)).joined())]"
 	self.contains = { c in
 		guard c.unicodeScalars.count == 1 else { return false }
 		return c.unicodeScalars.first.map(characterSet.contains) ?? false
 	}
 }
 }
 */
