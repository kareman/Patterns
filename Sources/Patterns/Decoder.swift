//
//  Decoder.swift
//  Patterns
//
//  Created by Kåre Morstøl on 14/08/2019.
//

extension Patterns.Match {
	public func decoder(with string: String) -> MatchDecoder {
		return MatchDecoder(match: self, string: string)
	}

	public struct MatchDecoder: Decoder {
		let match: Patterns.Match
		let string: String

		public var codingPath: [CodingKey] { return [] }
		public var userInfo: [CodingUserInfoKey: Any] { return [:] }

		public func container<Key>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
			return KeyedDecodingContainer(KDC(match: match, string: string))
		}

		public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
			fatalError()
		}

		public func singleValueContainer() throws -> SingleValueDecodingContainer {
			fatalError()
		}

		struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
			var codingPath: [CodingKey] = []
			var allKeys: [Key] = []
			let match: Patterns.Match
			let string: String

			func capture(for key: CodingKey) throws -> String {
				guard let range = match[one: key.stringValue] else {
					throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: ""))
				}
				return String(string[range])
			}

			func contains(_ key: Key) -> Bool {
				return match[one: key.stringValue] == nil
			}

			func decodeNil(forKey key: Key) throws -> Bool {
				return contains(key)
			}

			func decode<T>(_ t: T.Type, forKey key: Key) throws -> T where T: Decodable {
				fatalError()
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
