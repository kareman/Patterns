// Playground generated with 🏟 Arena (https://github.com/finestructure/arena)
// ℹ️ If running the playground fails with an error "no such module ..."
//    go to Product -> Build to re-trigger building the SPM package.
// ℹ️ Please restart Xcode if autocomplete is not working.

import Patterns

let text = """
I can eat glass and it doesn't hurt me.
ᛖᚴ ᚷᛖᛏ ᛖᛏᛁ ᚧ ᚷᛚᛖᚱ ᛘᚾ ᚦᛖᛋᛋ ᚨᚧ ᚡᛖ ᚱᚧᚨ ᛋᚨᚱ
Ek get etið gler án þess að verða sár.
Eg kan eta glas utan å skada meg.
ᛁᚳ᛫ᛗᚨᚷ᛫ᚷᛚᚨᛋ᛫ᛖᚩᛏᚪᚾ᛫ᚩᚾᛞ᛫ᚻᛁᛏ᛫ᚾᛖ᛫ᚻᛖᚪᚱᛗᛁᚪᚧ᛫ᛗᛖ᛬
Μπορώ να φάω σπασμένα γυαλιά χωρίς να πάθω τίποτα.
我能吞下玻璃而不伤身体。
我能吞下玻璃而不傷身體。
Góa ē-tàng chia̍h po-lê, mā bē tio̍h-siong.
私はガラスを食べられます。それは私を傷つけません。
나는 유리를 먹을 수 있어요. 그래도 아프지 않아요
काचं शक्नोम्यत्तुम् । नोपहिनस्ति माम् ॥
"""

let p = Capture(name: ">=6", letter.repeat(6...))
	/ Capture(name: "4...5", letter.repeat(4 ... 5))
	/ Capture(name: "2...3", letter.repeat(2 ... 3))
	/ Capture(name: "1", letter)

try showParserView(pattern: p, withText: text)
