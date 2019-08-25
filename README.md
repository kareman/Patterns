
<p align="center">
   <a href="https://developer.apple.com/swift/">
      <img src="https://img.shields.io/badge/Swift-5.1-orange.svg?style=flat" alt="Swift 5.1">
   </a>
   <a href="https://github.com/apple/swift-package-manager">
      <img src="https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg" alt="SPM">
   </a>
   <a href="https://github.com/Carthage/Carthage">
      <img src="https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat" alt="Carthage Compatible">
   </a>
</p>

# Patterns

Patterns is a Swift framework for finding text patterns, similar in functionality to regex.

Its primary goal is to be easier to read than regexes, and fully Unicode compliant.

## Features

- [x] Easier to read
- [x] Easier to write
- [x] Cross-platform
- [x] Negation 

## Examples

- [Parsing Unicode property data files](https://nottoobadsoftware.com/blog/textpicker/patterns/parsing_unicode_property_data_files/)

## Usage

### Defining patterns

`Literal("some text")` matches that exact text.

`OneOf("aeiouAEIOU")` matches any single character in that string.

```swift
OneOf(description: "lowercaseASCII") { character in
	character.isASCII && character.isLowercase
}
```

takes a closure `@escaping (Character) -> Bool)` and matches any character for which the closure returns `true`. The description parameter is only used when creating a textual representation of the pattern.

`digit.repeat(2)` matches 2 of that pattern in a row. `digit.repeat(0...1)` matches 0 or 1 (so it is optional), `digit.repeat(...2)` matches 0, 1 or 2 and `digit.repeat(2...)` matches 2 or more. These always match as many characters as possible, so a pattern like `digit.repeat(1...) digit` will never match anything because the repeated digit pattern will always take all the digits, leaving none left for the single digit pattern.

`a || b` first tries the pattern on the left. If that fails it tries the pattern on the right.

`Patterns(Literal("name: '"), letter.repeat(1...), Literal("'"))` matches a series of patterns. If that specific combination of patterns is invalid it will crash. You can use `try Patterns(verify: Literal("name: '"), letter.repeat(1...), Literal("'"))` to throw an error instead.

If your pattern contains several literals it might be easier to read using string interpolation: `Patterns("name: '\(letter.repeat(1...))'")`. This is the same as the previous example.

`Skip()` matches 0 or more characters until a match for the rest of the pattern up to the next `Skip`. So `Patterns("name: '\(Skip())'")` is a better version of the examples above if you also want to include names with non-letter characters.


### Predefined patterns

There are predefined patterns for all the boolean `is...` properties of Swift's `Character`: `letter`, `lowercase`, `uppercase`, `punctuation`, `whitespace`, `newline`, `hexDigit`, `digit`, `ascii`, `symbol`, `mathSymbol`, `currencySymbol`.

They all have the same name as the last part of the property, except for `wholeNumber`, which is renamed to `digit` because `wholeNumber` sounds more like an entire number than a single digit.

There is also `alphanumeric`, which is a `letter` or a `digit`.

`Line.start` matches at the beginning of the text, and after any newline characters. `Line.end` matches at the end of the text, and right before any newline characters. They both have a length of 0, which means the next pattern will start at the same position in the text.

`Line()` matches a single line, not including the newline characters.

`Word.boundary` matches the position right before or right after a word. Like `Line.start` and `Line.end` it also has a length of 0.


### Extracting data

All `Patterns` have a `.matches(in: String)` method which returns a lazy sequence of `Match` instances. Use their `.fullRange` property to access the full range matched by the pattern:

```swift
Patterns(Line()).matches(in: text).map { text[$0.fullRange] }
```

Often we are only interested in parts of a pattern. You can use the `Capture` pattern to assign a name to those parts:

```swift
let text = "This is a point: (43,7), so is (0,5). But my final point is (3,-1)."

let number = Patterns(OneOf("+-").repeat(0 ... 1), digit.repeat(1...))
let point = Patterns("(\(Capture(name: "x", number)),\(Capture(name: "y", number)))")

struct Point: Codable, Equatable {
	let x, y: Int
}

let points = try point.decode([Point].self, from: text)
```

If you don't want to create new types, you can use subscripting:

```swift
let pointsAsSubstrings = point.matches(in: text).map { match in
	(text[match[one: "x"]!], text[match[one: "y"]!])
}
```

You can also use `match[multiple: name]` if captures with that name may be matched multiple times. `match[one: name]` only returns the first capture of that name.


## Installation

### [Swift Package Manager](https://swift.org/package-manager/)

Add this to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/kareman/Patterns.git", .branch("master")),
]
```

### [CocoaPods](http://cocoapods.org)

Add to your Podfile:

```ruby
pod 'Patterns', :git => 'https://github.com/kareman/Patterns.git'
```

### [Carthage](https://github.com/Carthage/Carthage)

Add to your `Cartfile`:

```ogdl
github "kareman/Patterns"
```

Run `carthage update` to build the framework and drag the built `Patterns.framework` into your Xcode project. 

In your application targets’ “Build Phases” settings tab, click the “+” icon and choose “New Run Script Phase” and add the Framework path as mentioned in [Carthage Getting started Step 4, 5 and 6](https://github.com/Carthage/Carthage/blob/master/README.md#if-youre-building-for-ios-tvos-or-watchos)

### Manually

If you prefer not to use any dependency managers, you can integrate Patterns into your project manually. Just drag the `Sources` folder into your Xcode project.


## Contributing
Contributions are most welcome 🙌.

Especially suggestions for a better name. 

## License

MIT

```
Patterns
Copyright (c) 2019 NotTooBad Software kare@nottoobadsoftware.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
