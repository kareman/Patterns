// Playground generated with 🏟 Arena (https://github.com/finestructure/arena)
// ℹ️ If running the playground fails with an error "no such module ..."
//    go to Product -> Build to re-trigger building the SPM package.
// ℹ️ Please restart Xcode if autocomplete is not working.

import Patterns

let text = """
0   0.0   0.01
-0   +0   -0.0   +0.0
-123.456e+00   -123.456E+00   -123.456e-00   -123.456E-00
+123.456e+00   +123.456E+00   +123.456e-00   +123.456E-00
0   0.0   0.01
-123e+12   -123e-12
123.456e+00   123.456E+00
0x123E   0x123e
0x0123456789abcdef
0b0   0b1   0b0000   0b0001   0b11110000   0b0000_1111   0b1010_00_11
"""

let unsigned = digit+
let sign = "-" / "+"
let integer = Capture(name: "integer", sign¿ • unsigned)
let hexa = Capture(name: "hexa", "0x" • hexDigit+)
let binary = Capture(name: "binary", "0b" • OneOf("01") • OneOf("01_")*)
let floating = Capture(name: "floating", integer • "." • unsigned)
let scientific = floating • (("e" / "E") • integer)¿
let number = hexa / binary / floating / integer / unsigned / scientific

try showParserView(pattern: number, withText: text)
