//
//  Group.swift
//  Patterns
//
//  Created by Kåre Morstøl on 23/04/2019.
//

@usableFromInline
struct Group<Element> {
	@usableFromInline
	let contains: (Element) -> Bool

	@usableFromInline
	init(contains: @escaping (Element) -> Bool) {
		self.contains = contains
	}

	@usableFromInline
	func contains<S: Sequence>(contentsOf s: S) -> Bool where S.Element == Element {
		s.allSatisfy(contains)
	}
}

extension Group {
	@usableFromInline
	func union(_ other: Group) -> Group {
		Group { self.contains($0) || other.contains($0) }
	}

	@usableFromInline
	static func || (a: Group, b: Group) -> Group {
		a.union(b)
	}

	@usableFromInline
	func intersection(_ other: Group) -> Group {
		Group { self.contains($0) && other.contains($0) }
	}

	@usableFromInline
	func subtracting(_ other: Group) -> Group {
		Group { self.contains($0) && !other.contains($0) }
	}

	@usableFromInline
	func inverted() -> Group<Element> {
		Group { !self.contains($0) }
	}
}

extension Group where Element: Hashable {
	@usableFromInline
	init(contentsOf set: Set<Element>) {
		contains = set.contains
	}

	@usableFromInline
	init<S>(contentsOf sequence: S) where S: Sequence, Element == S.Element {
		self.init(contentsOf: Set(sequence))
	}
}
