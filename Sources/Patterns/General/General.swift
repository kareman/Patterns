//
//  Collections.swift
//  Patterns
//
//  Created by Kåre Morstøl on 24/09/16.
//

@usableFromInline
struct SearchCache<Element: Hashable> {
	@usableFromInline
	let length: Int
	@usableFromInline
	let skipTable: [Element: Int]
	// TODO: Store pattern in array

	@usableFromInline
	init<Target: BidirectionalCollection>(_ target: Target)
		where Target.SubSequence.Element == Element {
		length = target.count
		var skipTable = [Element: Int](minimumCapacity: length)
		for (i, c) in target.dropLast().enumerated() {
			skipTable[c] = length - i - 1
		}
		self.skipTable = skipTable
	}
}

extension BidirectionalCollection where Element: Hashable {
	/// Finds the next occurrence of `target` in this collection.
	/// - Parameters:
	///   - target: The sequence of elements to search for.
	///   - start: Where to start the search from.
	///   - cache: When searching for the same sequence multiple times, use a SearchCache for improved performance.
	/// - Returns: The range where `target` was found, or nil if not found.
	@inlinable
	func range<Target: BidirectionalCollection>
	(of target: Target, from start: Index? = nil, cache: SearchCache<Target.Element>? = nil) -> Range<Index>?
		where Target.Element == Element {
		// https://en.wikipedia.org/wiki/Boyer–Moore–Horspool_algorithm
		let cache = cache ?? SearchCache(target)
		guard cache.length > 0 else { return nil }

		var pos = self.index(start ?? self.startIndex, offsetBy: cache.length - 1, limitedBy: endIndex) ?? endIndex

		while pos < endIndex {
			var i = pos
			var p = target.index(before: target.endIndex)

			while self[i] == target[p] {
				if p == target.startIndex {
					return i ..< index(after: pos)
				} else {
					self.formIndex(before: &i)
					target.formIndex(before: &p)
				}
			}

			let advance = cache.skipTable[self[pos]] ?? cache.length
			pos = self.index(pos, offsetBy: advance, limitedBy: endIndex) ?? endIndex
		}

		return nil
	}
}

extension Collection {
	/// Returns the results of passing leading elements to `transform` until it returns nil.
	/// - Parameter transform: transforms each element, returns nil when it wants to stop.
	/// - Throws: Whatever `transform` throws.
	/// - Returns: An array of the transformed elements, not including the first `nil`.
	@inlinable
	func mapPrefix<T>(transform: (Element) throws -> T?) rethrows -> [T] {
		var result = [T]()
		for e in self {
			guard let transformed = try transform(e) else {
				return result
			}
			result.append(transformed)
		}
		return result
	}
}

extension Sequence {
	/// Returns an array containing the entire sequence.
	func array() -> [Element] { Array(self) }

	/// Returns the result of combining the elements using the given closure, if there are no nil elements.
	/// - Parameters:
	///   - initialResult: The value to use as the initial accumulating value.
	///   - updateAccumulatingResult: A closure that updates the accumulating value with an element of the sequence.
	///   - partialResult: The accumulating value.
	///   - unwrappedElement: An unwrapped element.
	/// - Returns: The final accumulated value, or nil if there were any nil elements.
	///            If the sequence has no elements, the result is initialResult.
	@inlinable
	func reduceIfNoNils<Result, T>(
		into initialResult: Result,
		_ updateAccumulatingResult: (_ partialResult: inout Result, _ unwrappedElement: T) throws -> Void)
		rethrows -> Result? where Element == Optional<T> {
		var accumulator = initialResult
		for element in self {
			guard let element = element else { return nil }
			try updateAccumulatingResult(&accumulator, element)
		}
		return accumulator
	}
}

/// Used like e.g. `let a = optional ?? fatalError("Message")`.
func ?? <T>(b: T?, a: @autoclosure () -> Never) -> T {
	if let b = b {
		return b
	}
	a()
}

/// Used like e.g. `let a = try optional ?? AnError()`.
func ?? <T, E: Error>(b: T?, a: @autoclosure () -> (E)) throws -> T {
	if let b = b {
		return b
	} else {
		throw a()
	}
}

extension BidirectionalCollection {
	/// Returns an index that is the specified distance from the given index, or nil if that index would be invalid.
	/// Never returns `endIndex`.
	@inlinable
	func validIndex(_ i: Index, offsetBy distance: Int) -> Index? {
		if distance < 0 {
			return index(i, offsetBy: distance, limitedBy: startIndex)
		}
		let newI = index(i, offsetBy: distance, limitedBy: endIndex)
		return newI == endIndex ? nil : newI
	}

	/// Offsets the given index by the specified distance, limited by `startIndex...endIndex`.
	/// - Returns: true if `index` has been offset by exactly `distance` steps; otherwise, false. When the return value is false, `index` is either `startIndex` or `endIndex`.
	@inlinable
	func formIndexSafely(_ index: inout Index, offsetBy distance: Int) -> Bool {
		if distance > 0 {
			return formIndex(&index, offsetBy: distance, limitedBy: endIndex)
		}
		return formIndex(&index, offsetBy: distance, limitedBy: startIndex)
	}
}

extension RangeReplaceableCollection where SubSequence == Self, Self: BidirectionalCollection {
	/// Removes the trailing range of elements for which `predicate` returns true.
	/// Stops as soon as `predicate` returns false.
	@inlinable
	mutating func removeSuffix(where predicate: (Element) -> Bool) {
		guard !isEmpty else { return }
		var i = index(before: endIndex)
		guard predicate(self[i]) else { return }
		while i > startIndex {
			formIndex(before: &i)
			if !predicate(self[i]) {
				self = self[...i]
				return
			}
		}
		removeAll()
	}
}

extension RangeReplaceableCollection {
	/// Shortcut for creating a RangeReplaceableCollection.
	///
	/// Example:
	/// ```
	/// let longIdentifier = Array {
	///    $0.append(...)
	///    $0.append(contentsOf:...)
	/// }
	/// ```
	init(compose: (inout Self) throws -> Void) rethrows {
		self.init()
		try compose(&self)
	}

	/// Shortcut for appending to a RangeReplaceableCollection.
	///
	/// Example:
	/// ```
	/// longIdentifier.append {
	///    $0.append(...)
	///    $0.append(contentsOf:...)
	/// }
	/// ```
	mutating func append(compose: (inout Self) throws -> Void) rethrows {
		try compose(&self)
	}
}
