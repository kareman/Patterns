//
//  Decoder.swift
//  Patterns
//
//  Created by Kåre Morstøl on 14/08/2019.
//

extension Parser where Input == String {
	/// Decodes all matches found in `string` into an array of `T`.
	@inlinable
	public func decode<T>(_ type: [T].Type, from string: String) throws -> [T] where T: Decodable {
		try matches(in: string).map { try $0.decode(type.Element.self, from: string) }
	}

	/// Decodes the first match found in `string` into a value of type `type`.
	@inlinable
	public func decodeFirst<T>(_ type: T.Type, from string: String) throws -> T? where T: Decodable {
		try match(in: string, at: string.startIndex).map { try $0.decode(type.self, from: string) }
	}
}

extension Parser.Match where Input == String {
	/// Decodes this match found in `string` into a value of type `type`.
	@inlinable
	public func decode<T>(_ type: T.Type, from string: String) throws -> T where T: Decodable {
		try type.init(from: MatchDecoder(match: self, string: string))
	}

	public struct MatchDecoder: Decoder {
		@usableFromInline
		let match: Parser.Match
		@usableFromInline
		let string: String

		public let codingPath: [CodingKey]
		public var userInfo: [CodingUserInfoKey: Any] { [:] }

		@inlinable
		init(match: Parser.Match, string: String, codingPath: [CodingKey] = []) {
			let namePrefix = codingPath.first.map { $0.stringValue }
			let captures = namePrefix.map { namePrefix in
				match.captures.flatMap { name, range in
					name?.hasPrefix(namePrefix) ?? false ? [(String(name!.dropFirst(namePrefix.count)), range)] : []
				}
			} ?? match.captures

			self.match = Parser.Match(endIndex: match.endIndex, captures: captures)
			self.string = string
			self.codingPath = codingPath
		}

		@inlinable
		public func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
			KeyedDecodingContainer(KDC(codingPath: codingPath, matchDecoder: self))
		}

		@inlinable
		public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
			UDC(codingPath: codingPath, values: match.captures.map { $0.range }, string: string)
		}

		@inlinable
		public func singleValueContainer() throws -> SingleValueDecodingContainer {
			guard match.captures.count < 2 else {
				let property = codingPath.map { "\($0.stringValue)" }.joined(separator: ".")
				throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription:
					"Property '\(property)' needs a single value, but multiple captures exists."))
			}
			let range = match.captures.first?.range ?? match.endIndex ..< match.endIndex
			return StringDecoder(string: String(string[range]), codingPath: codingPath)
		}

		@usableFromInline
		struct UDC: UnkeyedDecodingContainer {
			@usableFromInline
			var codingPath: [CodingKey]
			@usableFromInline
			let values: [Range<Input.Index>]
			@usableFromInline
			let string: String

			@usableFromInline
			init(codingPath: [CodingKey], values: [Range<Input.Index>], string: String) {
				self.codingPath = codingPath
				self.values = values
				self.string = string
			}

			@usableFromInline
			var count: Int? { values.count }
			@usableFromInline
			var isAtEnd: Bool { currentIndex >= values.endIndex }
			@usableFromInline
			var currentIndex: Int = 0

			@usableFromInline
			mutating func decodeNil() throws -> Bool { false }

			@usableFromInline
			mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type)
				throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
				fatalError("Not implemented yet. If you want to help with that, go to https://github.com/kareman/Patterns")
			}

			@usableFromInline
			mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
				fatalError("Not implemented yet. If you want to help with that, go to https://github.com/kareman/Patterns")
			}

			@usableFromInline
			mutating func superDecoder() throws -> Decoder {
				fatalError("Not implemented yet. If you want to help with that, go to https://github.com/kareman/Patterns")
			}

			@usableFromInline
			mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
				defer { currentIndex += 1 }
				let text = String(string[values[currentIndex]])
				return try type.init(from: StringDecoder(string: text, codingPath: codingPath))
			}

			@usableFromInline
			mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable & LosslessStringConvertible {
				guard let value = type.init(String(string[values[currentIndex]])) else {
					throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: ""))
				}
				currentIndex += 1
				return value
			}
		}

		@usableFromInline
		struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
			@usableFromInline
			var codingPath: [CodingKey] = []
			@usableFromInline
			var allKeys: [Key] {
				matchDecoder.match.captureNames.compactMap(Key.init(stringValue:))
			}

			@usableFromInline
			let matchDecoder: MatchDecoder

			@usableFromInline
			init(codingPath: [CodingKey] = [], matchDecoder: MatchDecoder) {
				self.codingPath = codingPath
				self.matchDecoder = matchDecoder
			}

			@usableFromInline
			func capture(for key: CodingKey) throws -> String {
				guard let range = matchDecoder.match[one: key.stringValue] else {
					throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: ""))
				}
				return String(matchDecoder.string[range])
			}

			@usableFromInline
			func contains(_ key: Key) -> Bool {
				matchDecoder.match[one: key.stringValue] == nil
			}

			@usableFromInline
			func decodeNil(forKey key: Key) throws -> Bool {
				contains(key)
			}

			@usableFromInline
			func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
				return try type.init(from:
					MatchDecoder(match: matchDecoder.match, string: matchDecoder.string, codingPath: codingPath + [key]))
			}

			@usableFromInline
			func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable & LosslessStringConvertible {
				guard let value = type.init(try capture(for: key)) else {
					throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: [key], debugDescription: ""))
				}
				return value
			}

			@usableFromInline
			func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type, forKey _: Key)
				throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
				fatalError("Not implemented yet. If you want to help with that, go to https://github.com/kareman/Patterns")
			}

			@usableFromInline
			func nestedUnkeyedContainer(forKey _: Key) throws -> UnkeyedDecodingContainer {
				fatalError("Not implemented yet. If you want to help with that, go to https://github.com/kareman/Patterns")
			}

			@usableFromInline
			func superDecoder() throws -> Decoder {
				fatalError("Not implemented yet. If you want to help with that, go to https://github.com/kareman/Patterns")
			}

			@usableFromInline
			func superDecoder(forKey _: Key) throws -> Decoder {
				fatalError("Not implemented yet. If you want to help with that, go to https://github.com/kareman/Patterns")
			}
		}
	}
}

@usableFromInline
struct StringDecoder: Decoder, SingleValueDecodingContainer {
	@usableFromInline
	let string: String
	@usableFromInline
	let codingPath: [CodingKey]
	@usableFromInline
	var userInfo: [CodingUserInfoKey: Any] = [:]

	@usableFromInline
	init(string: String, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any] = [:]) {
		self.string = string
		self.codingPath = codingPath
		self.userInfo = userInfo
	}

	@usableFromInline
	func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
		fatalError("Not implemented yet. If you want to help with that, go to https://github.com/kareman/Patterns")
	}

	@usableFromInline
	func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		fatalError("Not implemented yet. If you want to help with that, go to https://github.com/kareman/Patterns")
	}

	@usableFromInline
	func singleValueContainer() throws -> SingleValueDecodingContainer { self }

	@usableFromInline
	func decodeNil() -> Bool { false }

	@usableFromInline
	func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
		fatalError("Not implemented yet. If you want to help with that, go to https://github.com/kareman/Patterns")
	}

	@usableFromInline
	func decode<T>(_ type: T.Type) throws -> T where T: Decodable & LosslessStringConvertible {
		guard let value = type.init(string) else {
			throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: ""))
		}
		return value
	}
}
