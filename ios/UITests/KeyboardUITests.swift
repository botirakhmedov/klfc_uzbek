import XCTest

/// Drives the keyboard inside the simulator the way a person would: it switches the
/// system over to this keyboard, taps where the keys are drawn, and reads back what
/// landed in the text field. The unit tests cover the layout data; this covers the part
/// only a running keyboard can answer.
final class KeyboardUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Mirrors Layouts.swift. Row 0 is the number row.
    private let rows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["q", "ş", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ö"],
        ["⇧", "z", "x", "ç", "v", "b", "n", "m", "ğ", "⌫"],
    ]
    private let bottomRow: [(String, CGFloat)] = [
        ("?123", 1.5), ("🌐", 1), ("ʼ", 1), ("space", 4), (".", 1), ("⏎", 1.5),
    ]
    private let rowHeight: CGFloat = 48
    private let paddingTop: CGFloat = 4
    private let paddingBottom: CGFloat = 8

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        dismissSystemKeyboardTips()
        try selectOurKeyboard()
    }

    private var field: XCUIElement { app.textViews["tryField"] }

    /// iOS offers a one-off "slide to type" card the first time a keyboard appears.
    private func dismissSystemKeyboardTips() {
        let proceed = app.buttons["Continue"]
        if proceed.waitForExistence(timeout: 5) {
            proceed.tap()
        }
    }

    /// Cycle the globe key until the board on screen is ours, which we detect by typing
    /// a letter that only this keyboard has in that position.
    private func selectOurKeyboard() throws {
        field.tap()
        for _ in 0..<6 {
            if typedProbeIsOurs() { return }
            let globe = app.keyboards.buttons["Next keyboard"]
            if globe.exists {
                globe.tap()
            } else {
                tapKeyboard(x: 0.15, row: 4)
            }
            sleep(1)
        }
        throw XCTSkip("could not switch the simulator to the keyboard under test")
    }

    private func typedProbeIsOurs() -> Bool {
        clearField()
        tapKey("ş")
        let value = (field.value as? String) ?? ""
        clearField()
        return value == "ş"
    }

    private func clearField() {
        guard let value = field.value as? String, !value.isEmpty else { return }
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
    }

    // MARK: - tapping the drawn keys

    private func keyboardFrame() -> CGRect {
        let board = app.keyboards.element(boundBy: 0)
        return board.exists ? board.frame : CGRect.zero
    }

    private func tapKeyboard(x: CGFloat, row: Int) {
        let frame = keyboardFrame()
        guard frame.height > 0 else { return }
        let rowCount = CGFloat(rows.count + 1)
        let usable = frame.height - paddingTop - paddingBottom
        let y = (paddingTop + usable / rowCount * (CGFloat(row) + 0.5)) / frame.height
        app.keyboards.element(boundBy: 0)
            .coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
            .tap()
    }

    private func tapKey(_ label: String) {
        for (rowIndex, row) in rows.enumerated() {
            if let column = row.firstIndex(of: label) {
                tapKeyboard(x: (CGFloat(column) + 0.5) / 10, row: rowIndex)
                return
            }
        }
        var offset: CGFloat = 0
        let total = bottomRow.reduce(CGFloat(0)) { $0 + $1.1 }
        for (name, weight) in bottomRow {
            if name == label {
                tapKeyboard(x: (offset + weight / 2) / total, row: rows.count)
                return
            }
            offset += weight
        }
        XCTFail("no key labelled \(label)")
    }

    // MARK: - tests

    func testTypesTheFourNewLettersAndTheTutuqBelgisi() {
        field.tap()
        for key in ["ş", "ö", "ğ", "ç", "ʼ"] { tapKey(key) }
        XCTAssertEqual(field.value as? String, "şöğç\u{02BC}")
    }

    func testShiftAppliesToOneLetterOnly() {
        field.tap()
        tapKey("⇧")
        tapKey("ş")
        tapKey("ö")
        XCTAssertEqual(field.value as? String, "Şö")
    }

    func testTheNumberRowTypesDigits() {
        field.tap()
        tapKey("1")
        tapKey("0")
        XCTAssertEqual(field.value as? String, "10")
    }

    func testBackspaceRemovesOneCharacter() {
        field.tap()
        tapKey("ʼ")
        tapKey("ğ")
        tapKey("⌫")
        XCTAssertEqual(field.value as? String, "\u{02BC}")
    }
}
