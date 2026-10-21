import CoreGraphics
import Foundation

/// What a key does when it is released.
enum KeyAction {
    case output, shift, delete, enter, space, switchPage, nextKeyboard
}

enum Page {
    case letters, symbols, moreSymbols
}

/// One key on the board.
///
/// `label` is what the key shows, `output` what it types; they differ only where the two
/// cannot be the same, such as the space bar. `alternates` are reachable with a long
/// press — `w` and `c` live under `ş` and `ç`, because neither is part of the 2026
/// alphabet but both are needed the moment someone types a URL or an English word.
struct Key {
    let label: String
    let output: String
    let action: KeyAction
    let weight: CGFloat
    let alternates: [String]
    let isLetter: Bool
    let pageTarget: Page?
    /// Printed small in the key's corner; defaults to the first alternate.
    let hint: String?

    init(
        _ label: String,
        output: String? = nil,
        action: KeyAction = .output,
        weight: CGFloat = 1,
        alternates: [String] = [],
        isLetter: Bool = false,
        pageTarget: Page? = nil,
        hint: String? = nil
    ) {
        self.label = label
        self.output = output ?? label
        self.action = action
        self.weight = weight
        self.alternates = alternates
        self.isLetter = isLetter
        self.pageTarget = pageTarget
        self.hint = hint
    }
}

private func letter(_ label: String, _ alternates: String..., hint: String? = nil) -> Key {
    Key(label, alternates: alternates, isLetter: true, hint: hint)
}

private func sym(_ label: String, _ alternates: String...) -> Key {
    Key(label, alternates: alternates)
}

/// U+02BC MODIFIER LETTER APOSTROPHE — the tutuq belgisi of the 2026 alphabet.
let tutuq = "\u{02BC}"

enum Layouts {

    /// The 28 letters of the 2026 alphabet, in the same positions as the desktop QŞERTY
    /// layout: ş where w was, ç where c was, with ö and ğ taking the ends of the home and
    /// bottom rows. Ten columns throughout, and a number row on top, so the board is as
    /// tall and as full as the stock one people are used to.
    private static let letters: [[Key]] = [
        [sym("1"), sym("2"), sym("3"), sym("4"), sym("5"),
         sym("6"), sym("7"), sym("8"), sym("9"), sym("0")],
        [letter("q"), letter("ş", "w"), letter("e"), letter("r"), letter("t"),
         letter("y"), letter("u"), letter("i"), letter("o"), letter("p")],
        [letter("a"), letter("s"), letter("d"), letter("f"), letter("g"),
         letter("h"), letter("j"), letter("k"), letter("l"), letter("ö")],
        // Eight letters on the bottom row leave no room for the wide shift and backspace
        // keys other boards have; keeping every row ten units wide matters more, because
        // it is what makes the keys line up into a grid.
        [Key("⇧", action: .shift),
         letter("z"), letter("x"), letter("ç", "c"), letter("v"),
         letter("b"), letter("n"), letter("m"), letter("ğ"),
         Key("⌫", action: .delete)],
        [Key("?123", action: .switchPage, weight: 1.5, pageTarget: .symbols),
         Key("🌐", action: .nextKeyboard),
         Key(tutuq, alternates: ["'", "\u{2019}", "\""]),
         Key("", output: " ", action: .space, weight: 4),
         sym(".", ",", "?", "!", "-"),
         Key("⏎", action: .enter, weight: 1.5)],
    ]

    private static let symbols: [[Key]] = [
        [sym("1"), sym("2"), sym("3"), sym("4"), sym("5"),
         sym("6"), sym("7"), sym("8"), sym("9"), sym("0")],
        [sym("@"), sym("#"), sym("$", "€", "₽", "£"), sym("%"), sym("&"),
         sym("-", "_", "–", "—"), sym("+", "±"), sym("("), sym(")"), sym("/")],
        [Key("=\\<", action: .switchPage, weight: 1.5, pageTarget: .moreSymbols),
         sym("*"), sym("\"", "“", "”", "«", "»"), sym("'", tutuq, "\u{2019}"),
         sym(":"), sym(";"), sym("!"), sym("?"),
         Key("⌫", action: .delete, weight: 1.5)],
        [Key("ABC", action: .switchPage, weight: 1.5, pageTarget: .letters),
         Key("🌐", action: .nextKeyboard),
         sym(","),
         Key("", output: " ", action: .space, weight: 4),
         sym("."),
         Key("⏎", action: .enter, weight: 1.5)],
    ]

    private static let moreSymbols: [[Key]] = [
        [sym("~"), sym("`"), sym("|"), sym("•"), sym("√"),
         sym("π"), sym("÷"), sym("×"), sym("¶"), sym("∆")],
        [sym("£"), sym("¢"), sym("€"), sym("¥"), sym("^"),
         sym("°"), sym("="), sym("{"), sym("}"), sym("\\")],
        [Key("?123", action: .switchPage, weight: 1.5, pageTarget: .symbols),
         sym("©"), sym("®"), sym("™"), sym("℅"),
         sym("["), sym("]"), sym("<"), sym(">"),
         Key("⌫", action: .delete, weight: 1.5)],
        [Key("ABC", action: .switchPage, weight: 1.5, pageTarget: .letters),
         Key("🌐", action: .nextKeyboard),
         sym(","),
         Key("", output: " ", action: .space, weight: 4),
         sym("."),
         Key("⏎", action: .enter, weight: 1.5)],
    ]

    static func rows(_ page: Page) -> [[Key]] {
        switch page {
        case .letters: return letters
        case .symbols: return symbols
        case .moreSymbols: return moreSymbols
        }
    }

    /// Every letter the board must be able to produce, used by the unit tests.
    static let alphabet = "abdefghijklmnopqrstuvxyzöğşç"
}
