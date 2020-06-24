//
//  Group.swift
//  Patterns
//
//  Created by Kåre Morstøl on 23/04/2019.
//

/// Works like a set, except it cannot list its contents.
/// It can only tell whether or not it contains a specific element.
@usableFromInline
struct Group<Element> {
	/// Returns true if this group contains `element`.
	@usableFromInline
	let contains: (Element) -> Bool

	/// A new group containing only elements for which `contains` returns true.
	@usableFromInline
	init(contains: @escaping (Element) -> Bool) {
		self.contains = contains
	}

	/// Returns true if this group contains all the elements in `sequence`.
	@usableFromInline
	func contains<S: Sequence>(contentsOf sequence: S) -> Bool where S.Element == Element {
		sequence.allSatisfy(contains)
	}
}

extension Group {
	/// Returns a group which contains all the elements of `self` and `other`.
	@usableFromInline
	func union(_ other: Group) -> Group {
		Group { self.contains($0) || other.contains($0) }
	}

	@usableFromInline
	static func || (a: Group, b: Group) -> Group {
		a.union(b)
	}

	/// Returns a group containing only elements that are both in `self` and `other`.
	@usableFromInline
	func intersection(_ other: Group) -> Group {
		Group { self.contains($0) && other.contains($0) }
	}

	/// Returns a group containing only elements that are in `self` but not `other`.
	@usableFromInline
	func subtracting(_ other: Group) -> Group {
		Group { self.contains($0) && !other.contains($0) }
	}

	/// Returns a group containing only elements that _not_ in `self`.
	@usableFromInline
	func inverted() -> Group<Element> {
		Group { !self.contains($0) }
	}
}

extension Group where Element: Hashable {
	/// A new group containing only elements that are in `set`.
	@usableFromInline
	init(contentsOf set: Set<Element>) {
		contains = set.contains
	}

	/// A new group containing only elements that are in `sequence`.
	@usableFromInline
	init<S>(contentsOf sequence: S) where S: Sequence, Element == S.Element {
		self.init(contentsOf: Set(sequence))
	}
}
