//
//  Collections.swift
//  Patterns
//
//  Created by Kåre Morstøl on 24/09/16.
//
//

public struct SearchCache<Element: Hashable> {
	let length: Int
	let skipTable: [Element: Int]

	public init<Pattern: BidirectionalCollection>(pattern: Pattern)
		where Pattern.SubSequence.Element == Element {
		length = pattern.count
		var skipTable = [Element: Int](minimumCapacity: length)
		for (i, c) in pattern.dropLast().enumerated() {
			skipTable[c] = length - i - 1
		}
		self.skipTable = skipTable
	}
}

// https://github.com/raywenderlich/swift-algorithm-club/tree/master/Boyer-Moore
extension BidirectionalCollection where Element: Hashable {
	public func ranges<Pattern: BidirectionalCollection>
	(of pattern: Pattern, from start: Index? = nil, cache: SearchCache<Pattern.Element>? = nil) -> [Range<Index>]
		where Pattern.Element == Element {
		let cache = cache ?? SearchCache(pattern: pattern)
		guard cache.length > 0 else { return [] }

		var pos = self.index(start ?? self.startIndex, offsetBy: cache.length - 1, limitedBy: endIndex) ?? endIndex
		var result = [Range<Index>]()

		while pos < endIndex {
			var i = pos
			var p = pattern.index(before: pattern.endIndex)

			while self[i] == pattern[p] {
				if p == pattern.startIndex {
					result.append(i ..< index(after: pos))
					break
				} else {
					self.formIndex(before: &i)
					pattern.formIndex(before: &p)
				}
			}

			let advance = cache.skipTable[self[pos]] ?? cache.length
			pos = self.index(pos, offsetBy: advance, limitedBy: endIndex) ?? endIndex
		}

		return result
	}

	public func range<Pattern: BidirectionalCollection>
	(of pattern: Pattern, from start: Index? = nil, cache: SearchCache<Pattern.Element>? = nil) -> Range<Index>?
		where Pattern.Element == Element {
		let cache = cache ?? SearchCache(pattern: pattern)
		guard cache.length > 0 else { return nil }

		var pos = self.index(start ?? self.startIndex, offsetBy: cache.length - 1, limitedBy: endIndex) ?? endIndex

		while pos < endIndex {
			var i = pos
			var p = pattern.index(before: pattern.endIndex)

			while self[i] == pattern[p] {
				if p == pattern.startIndex {
					return i ..< index(after: pos)
				} else {
					self.formIndex(before: &i)
					pattern.formIndex(before: &p)
				}
			}

			let advance = cache.skipTable[self[pos]] ?? cache.length
			pos = self.index(pos, offsetBy: advance, limitedBy: endIndex) ?? endIndex
		}

		return nil
	}
}

extension Collection {
	/// Returns the length of the range in this Collection.
	func distance(of range: Range<Index>) -> Int {
		return distance(from: range.lowerBound, to: range.upperBound)
	}

	/// The second element of the collection.
	var second: Element? {
		guard let index = index(startIndex, offsetBy: 1, limitedBy: endIndex), index != endIndex else {
			return nil
		}
		return self[index]
	}

	var fullRange: Range<Index> {
		return startIndex ..< endIndex
	}
}

extension Sequence {
	/// Returns an array containing the entire sequence.
	public func array() -> [Element] {
		return Array(self)
	}
}

extension Range: Comparable {
	public static func < (l: Range<Bound>, r: Range<Bound>) -> Bool {
		return (l.lowerBound == r.lowerBound) ? (l.upperBound < r.upperBound) : (l.lowerBound < r.lowerBound)
	}
}

func ?? <T>(b: T?, a: @autoclosure () -> Never) -> T {
	if let b = b {
		return b
	}
	a()
}

extension BidirectionalCollection {
	func validIndex(_ i: Index, offsetBy distance: Int) -> Index? {
		if distance < 0 {
			return index(i, offsetBy: distance, limitedBy: startIndex)
		}
		let newI = index(i, offsetBy: distance, limitedBy: endIndex)
		return newI == endIndex ? nil : newI
	}

	func dropLast(while handler: (Element) -> Bool) -> SubSequence {
		guard let i = self.lastIndex(where: { !handler($0) }) else {
			return self[..<self.startIndex]
		}
		return self[...i]
	}

	func formIndexSafely(_ i: inout Index, offsetBy distance: Int) -> Bool {
		if distance > 0 {
			return formIndex(&i, offsetBy: distance, limitedBy: endIndex)
		} else {
			return formIndex(&i, offsetBy: distance, limitedBy: startIndex)
		}
	}
}

// from https://github.com/apple/swift/blob/da61cc8cdf7aa2bfb3ab03200c52c4d371dc6751/stdlib/public/core/Collection.swift#L1527
extension Collection {
	@inlinable
	__consuming func splitWhileKeepingSeparators(
		maxSplits: Int = Int.max,
		omittingEmptySubsequences: Bool = true,
		whereSeparator isSeparator: (Element) throws -> Bool) rethrows -> [SubSequence] {
		var result: [SubSequence] = []
		var subSequenceStart: Index = startIndex

		func appendSubsequence(end: Index) -> Bool {
			if subSequenceStart == end, omittingEmptySubsequences {
				return false
			}
			result.append(self[subSequenceStart ..< end])
			return true
		}

		if maxSplits == 0 || isEmpty {
			_ = appendSubsequence(end: endIndex)
			return result
		}

		var subSequenceEnd = subSequenceStart
		let cachedEndIndex = endIndex
		while subSequenceEnd != cachedEndIndex {
			if try isSeparator(self[subSequenceEnd]) {
				let didAppend = appendSubsequence(end: subSequenceEnd)
				subSequenceStart = subSequenceEnd
				formIndex(after: &subSequenceEnd)
				if didAppend, result.count == maxSplits {
					break
				}
				continue
			}
			formIndex(after: &subSequenceEnd)
		}

		if subSequenceStart != cachedEndIndex || !omittingEmptySubsequences {
			result.append(self[subSequenceStart ..< cachedEndIndex])
		}

		return result
	}
}

extension RangeReplaceableCollection {
	mutating func popFirst(where shouldBeRemoved: (Element) throws -> Bool) rethrows -> Element? {
		guard let index = try firstIndex(where: shouldBeRemoved) else { return nil }
		return remove(at: index)
	}
}

extension RangeReplaceableCollection {
	init(compose: (inout Self) -> Void) {
		self.init()
		compose(&self)
	}

	static func += (lhs: inout Self, rhs: Element) {
		lhs.append(rhs)
	}

	mutating func append(compose: (inout Self) -> Void) {
		compose(&self)
	}
}
