package uz.alifbo.keyboard

/** What a key does when it is released. */
enum class KeyAction { OUTPUT, SHIFT, DELETE, ENTER, SPACE, SWITCH_PAGE, SWITCH_IME, SETTINGS }

/**
 * One key on the board.
 *
 * [label] is what the key shows, [output] what it types. They differ for the dead-simple
 * cases only (space, comma on the symbol pages), so [output] defaults to [label].
 *
 * [alternates] are reachable with a long press. The digits sit on the top letter row and
 * `w` and `c` hide under `ş` and `ç`: neither is part of the 2026 alphabet, but both are
 * needed the moment someone types a URL or an English word.
 */
data class Key(
    val label: String,
    val output: String = label,
    val action: KeyAction = KeyAction.OUTPUT,
    val weight: Float = 1f,
    val alternates: List<String> = emptyList(),
    val isLetter: Boolean = false,
    val pageTarget: Page? = null,
    /** Printed small in the key's corner; defaults to the first alternate. */
    val hint: String? = null,
)

enum class Page { LETTERS, SYMBOLS, MORE_SYMBOLS }

private fun letter(label: String, vararg alternates: String, hint: String? = null) =
    Key(label, isLetter = true, alternates = alternates.toList(), hint = hint)

private fun sym(label: String, vararg alternates: String) =
    Key(label, alternates = alternates.toList())

/** U+02BC MODIFIER LETTER APOSTROPHE — the tutuq belgisi of the 2026 alphabet. */
const val TUTUQ = "ʼ"

object Layouts {

    /**
     * The 28 letters of the 2026 alphabet, in the same positions as the desktop QŞERTY
     * layout: ş where w was, ç where c was, with ö and ğ taking the ends of the home and
     * bottom rows. Ten columns throughout, and a number row on top, so the board is as
     * tall and as full as the stock one people are used to.
     */
    private val letters: List<List<Key>> = listOf(
        listOf(
            sym("1"), sym("2"), sym("3"), sym("4"), sym("5"),
            sym("6"), sym("7"), sym("8"), sym("9"), sym("0"),
        ),
        listOf(
            letter("q"), letter("ş", "w"), letter("e"), letter("r"),
            letter("t"), letter("y"), letter("u"), letter("i"),
            letter("o"), letter("p"),
        ),
        listOf(
            letter("a"), letter("s"), letter("d"), letter("f"), letter("g"),
            letter("h"), letter("j"), letter("k"), letter("l"), letter("ö"),
        ),
        // Eight letters on the bottom row leave no room for the wide shift and backspace
        // keys other boards have; keeping every row ten units wide matters more, because
        // it is what makes the keys line up into a grid.
        listOf(
            Key("⇧", action = KeyAction.SHIFT),
            letter("z"), letter("x"), letter("ç", "c"), letter("v"),
            letter("b"), letter("n"), letter("m"), letter("ğ"),
            Key("⌫", action = KeyAction.DELETE),
        ),
        listOf(
            Key("?123", action = KeyAction.SWITCH_PAGE, weight = 1.5f, pageTarget = Page.SYMBOLS),
            Key("🌐", action = KeyAction.SWITCH_IME),
            Key(TUTUQ, alternates = listOf("'", "’", "\"")),
            Key("", output = " ", action = KeyAction.SPACE, weight = 4f),
            sym(".", ",", "?", "!", "-"),
            Key("⏎", action = KeyAction.ENTER, weight = 1.5f),
        ),
    )

    private val symbols: List<List<Key>> = listOf(
        listOf(sym("1"), sym("2"), sym("3"), sym("4"), sym("5"),
               sym("6"), sym("7"), sym("8"), sym("9"), sym("0")),
        listOf(sym("@"), sym("#"), sym("$", "€", "₽", "£"), sym("%"), sym("&"),
               sym("-", "_", "–", "—"), sym("+", "±"), sym("("), sym(")"), sym("/")),
        listOf(
            Key("=\\<", action = KeyAction.SWITCH_PAGE, weight = 1.5f, pageTarget = Page.MORE_SYMBOLS),
            sym("*"), sym("\"", "“", "”", "«", "»"),
            sym("'", TUTUQ, "’"), sym(":"), sym(";"), sym("!"), sym("?"),
            Key("⌫", action = KeyAction.DELETE, weight = 1.5f),
        ),
        listOf(
            Key("ABC", action = KeyAction.SWITCH_PAGE, weight = 1.5f, pageTarget = Page.LETTERS),
            Key("🌐", action = KeyAction.SWITCH_IME),
            sym(","),
            Key("", output = " ", action = KeyAction.SPACE, weight = 4f),
            sym("."),
            Key("⏎", action = KeyAction.ENTER, weight = 1.5f),
        ),
    )

    private val moreSymbols: List<List<Key>> = listOf(
        listOf(sym("~"), sym("`"), sym("|"), sym("•"), sym("√"),
               sym("π"), sym("÷"), sym("×"), sym("¶"), sym("∆")),
        listOf(sym("£"), sym("¢"), sym("€"), sym("¥"), sym("^"),
               sym("°"), sym("="), sym("{"), sym("}"), sym("\\")),
        listOf(
            Key("?123", action = KeyAction.SWITCH_PAGE, weight = 1.5f, pageTarget = Page.SYMBOLS),
            sym("©"), sym("®"), sym("™"), sym("℅"),
            sym("["), sym("]"), sym("<"), sym(">"),
            Key("⌫", action = KeyAction.DELETE, weight = 1.5f),
        ),
        listOf(
            Key("ABC", action = KeyAction.SWITCH_PAGE, weight = 1.5f, pageTarget = Page.LETTERS),
            Key("🌐", action = KeyAction.SWITCH_IME),
            sym(","),
            Key("", output = " ", action = KeyAction.SPACE, weight = 4f),
            sym("."),
            Key("⏎", action = KeyAction.ENTER, weight = 1.5f),
        ),
    )

    fun rows(page: Page): List<List<Key>> = when (page) {
        Page.LETTERS -> letters
        Page.SYMBOLS -> symbols
        Page.MORE_SYMBOLS -> moreSymbols
    }

    /** Every letter the board must be able to produce, used by the unit test. */
    val alphabet = "abdefghijklmnopqrstuvxyzöğşç"
}
