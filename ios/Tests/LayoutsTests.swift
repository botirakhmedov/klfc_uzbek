import XCTest

final class LayoutsTests: XCTestCase {

    private func reachable(_ page: Page) -> Set<String> {
        Set(Layouts.rows(page).flatMap { $0 }.flatMap { [$0.output] + $0.alternates })
    }

    func testEveryLetterOfTheAlphabetIsOnTheLetterPage() {
        let keys = reachable(.letters)
        let missing = Layouts.alphabet.filter { !keys.contains(String($0)) }
        XCTAssertEqual(String(missing), "", "letters missing from the board")
    }

    func testTheTutuqBelgisiIsU02BCAndHasItsOwnKey() {
        XCTAssertEqual(tutuq, "\u{02BC}")
        let ownKeys = Layouts.rows(.letters).flatMap { $0 }.filter { $0.output == tutuq }
        XCTAssertEqual(ownKeys.count, 1)
    }

    func testWAndCAreReachableEvenThoughTheyLeftTheAlphabet() {
        let keys = reachable(.letters)
        XCTAssertTrue(keys.contains("w"), "w is unreachable")
        XCTAssertTrue(keys.contains("c"), "c is unreachable")
    }

    func testEveryLetterRowSpansTheSameWidth() {
        let widths = Layouts.rows(.letters).map { row in row.reduce(CGFloat(0)) { $0 + $1.weight } }
        XCTAssertEqual(Set(widths).count, 1, "rows have different widths: \(widths)")
    }

    func testEveryPageCanBeLeftAgain() {
        for page in [Page.symbols, .moreSymbols] {
            let targets = Layouts.rows(page).flatMap { $0 }.compactMap { $0.pageTarget }
            XCTAssertTrue(targets.contains(.letters), "\(page) has no way back to letters")
        }
    }

    func testDeleteAndEnterExistOnEveryPage() {
        for page in [Page.letters, .symbols, .moreSymbols] {
            let actions = Layouts.rows(page).flatMap { $0 }.map(\.action)
            XCTAssertTrue(actions.contains(where: { if case .delete = $0 { return true }; return false }),
                          "\(page) has no delete")
            XCTAssertTrue(actions.contains(where: { if case .enter = $0 { return true }; return false }),
                          "\(page) has no enter")
        }
    }

    /// The iOS and Android boards must stay the same keyboard, not two that drifted apart.
    func testTheLetterPageMatchesTheAndroidBoard() {
        let rows = Layouts.rows(.letters).map { row in row.map(\.label).joined(separator: " ") }
        XCTAssertEqual(rows[0], "1 2 3 4 5 6 7 8 9 0")
        XCTAssertEqual(rows[1], "q ş e r t y u i o p")
        XCTAssertEqual(rows[2], "a s d f g h j k l ö")
        XCTAssertEqual(rows[3], "⇧ z x ç v b n m ğ ⌫")
    }
}
