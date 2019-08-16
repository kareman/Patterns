//
//  Decoder.swift
//  Patterns
//
//  Created by Kåre Morstøl on 14/08/2019.
//

extension Patterns.Match {
	public func decode<T>(_ type: T.Type, from string: String) throws -> T where T: Decodable {
		return try type.init(from: MatchDecoder(match: self, string: string))
	}

	public struct MatchDecoder: Decoder {
		let match: Patterns.Match
		let string: String

		public let codingPath: [CodingKey]
		public var userInfo: [CodingUserInfoKey: Any] { return [:] }

		init(match: Patterns.Match, string: String, codingPath: [CodingKey] = []) {
			let namePrefix = codingPath.first.map { $0.stringValue }
			let captures = namePrefix.map { namePrefix in
				match.captures.flatMap { name, range in
					name?.hasPrefix(namePrefix) ?? false ? [(String(name!.dropFirst(namePrefix.count)), range)] : []
				}
			} ?? match.captures

			self.match = Patterns.Match(fullRange: match.fullRange, captures: captures)
			self.string = string
			self.codingPath = codingPath
		}

		public func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
			return KeyedDecodingContainer(KDC(codingPath: codingPath, matchDecoder: self))
		}

		public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
			return UDC(codingPath: codingPath, values: match.captures.map { $0.range }, string: string)
		}

		public func singleValueContainer() throws -> SingleValueDecodingContainer {
			fatalError()
		}

		struct UDC: UnkeyedDecodingContainer {
			var codingPath: [CodingKey]
			let values: [ParsedRange]
			let string: String

			var count: Int? { values.count }
			var isAtEnd: Bool { currentIndex >= values.endIndex }
			var currentIndex: Int = 0

			mutating func decodeNil() throws -> Bool { false }

			mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
				fatalError()
			}

			mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
				fatalError()
			}

			mutating func superDecoder() throws -> Decoder {
				fatalError()
			}

			mutating func decode<T>(_ t: T.Type) throws -> T where T: Decodable {
				defer { currentIndex += 1 }
				return try t.init(from: StringDecoder(string: String(string[values[currentIndex]]), codingPath: codingPath))
			}

			mutating func decode<T>(_ t: T.Type) throws -> T where T: Decodable & LosslessStringConvertible {
				guard let value = t.init(String(string[values[currentIndex]])) else {
					throw DecodingError.typeMismatch(t, DecodingError.Context(codingPath: codingPath, debugDescription: ""))
				}
				currentIndex += 1
				return value
			}
		}

		struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
			var codingPath: [CodingKey] = []
			var allKeys: [Key] {
				matchDecoder.match.names.compactMap(Key.init(stringValue:))
			}

			let matchDecoder: MatchDecoder

			func capture(for key: CodingKey) throws -> String {
				guard let range = matchDecoder.match[one: key.stringValue] else {
					throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: ""))
				}
				return String(matchDecoder.string[range])
			}

			func contains(_ key: Key) -> Bool {
				return matchDecoder.match[one: key.stringValue] == nil
			}

			func decodeNil(forKey key: Key) throws -> Bool {
				return contains(key)
			}

			func decode<T>(_ t: T.Type, forKey key: Key) throws -> T where T: Decodable {
				return try t.init(from: MatchDecoder(match: matchDecoder.match, string: matchDecoder.string, codingPath: codingPath + [key]))
			}

			func decode<T>(_ t: T.Type, forKey key: Key) throws -> T where T: Decodable & LosslessStringConvertible {
				guard let value = t.init(try capture(for: key)) else {
					throw DecodingError.typeMismatch(t, DecodingError.Context(codingPath: [key], debugDescription: ""))
				}
				return value
			}

			func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type, forKey _: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
				fatalError()
			}

			func nestedUnkeyedContainer(forKey _: Key) throws -> UnkeyedDecodingContainer {
				fatalError()
			}

			func superDecoder() throws -> Decoder {
				fatalError()
			}

			func superDecoder(forKey _: Key) throws -> Decoder {
				fatalError()
			}
		}
	}
}

struct StringDecoder: Decoder, SingleValueDecodingContainer {
	let string: String
	let codingPath: [CodingKey]
	var userInfo: [CodingUserInfoKey: Any] = [:]

	func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
		fatalError()
	}

	func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		fatalError()
	}

	func singleValueContainer() throws -> SingleValueDecodingContainer {
		self
	}

	func decodeNil() -> Bool { false }

	func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
		fatalError()
	}

	func decode<T>(_ type: T.Type) throws -> T where T: Decodable & LosslessStringConvertible {
		guard let value = type.init(string) else {
			throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: ""))
		}
		return value
	}
}
