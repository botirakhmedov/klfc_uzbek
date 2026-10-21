import UIKit

/// Where the shift key currently stands.
enum ShiftState {
    case off, on, locked
}

protocol KeyboardLayoutViewDelegate: AnyObject {
    func keyboard(_ view: KeyboardLayoutView, didProduce text: String)
    func keyboardDidDelete(_ view: KeyboardLayoutView)
    func keyboardDidReturn(_ view: KeyboardLayoutView)
    func keyboardDidRequestNextKeyboard(_ view: KeyboardLayoutView)
}

/// Draws the board and turns touches into key presses.
///
/// Everything is drawn into one view rather than built from buttons: the board is redrawn
/// on every shift change and every page switch, and one canvas keeps that cheap and keeps
/// the key geometry in a single place.
final class KeyboardLayoutView: UIView {

    weak var delegate: KeyboardLayoutViewDelegate?

    private(set) var page: Page = .letters
    private(set) var shift: ShiftState = .off

    private struct Placed {
        let key: Key
        let rect: CGRect
    }

    private var placed: [Placed] = []
    private var pressedIndex: Int?
    private var lastShiftTap: TimeInterval = 0

    private let gapX: CGFloat = 3
    private let gapY: CGFloat = 5
    private let radius: CGFloat = 5
    let rowHeight: CGFloat = 48
    private let paddingTop: CGFloat = 4
    private let paddingBottom: CGFloat = 8

    private var longPressTimer: Timer?
    private var deleteTimer: Timer?
    private var alternates: AlternatesView?

    /// The height this board needs, which the view controller pins its constraint to.
    var preferredHeight: CGFloat {
        rowHeight * CGFloat(Layouts.rows(page).count) + paddingTop + paddingBottom
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = false
        backgroundColor = Theme.background
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutKeys()
        setNeedsDisplay()
    }

    private func layoutKeys() {
        let rows = Layouts.rows(page)
        guard !rows.isEmpty, bounds.width > 0 else { return }
        let rowH = (bounds.height - paddingTop - paddingBottom) / CGFloat(rows.count)
        var out: [Placed] = []
        for (rowIndex, row) in rows.enumerated() {
            let total = row.reduce(CGFloat(0)) { $0 + $1.weight }
            let unit = bounds.width / total
            var x: CGFloat = 0
            let y = paddingTop + CGFloat(rowIndex) * rowH
            for key in row {
                let w = unit * key.weight
                out.append(Placed(key: key, rect: CGRect(
                    x: x + gapX, y: y + gapY,
                    width: w - gapX * 2, height: rowH - gapY * 2
                )))
                x += w
            }
        }
        placed = out
    }

    func setPage(_ next: Page) {
        page = next
        if next != .letters { shift = .off }
        invalidateIntrinsicContentSize()
        layoutKeys()
        setNeedsDisplay()
    }

    /// Reset to a lower-case letter board; called when a new text field is opened.
    func reset() {
        page = .letters
        shift = .off
        invalidateIntrinsicContentSize()
        layoutKeys()
        setNeedsDisplay()
    }

    func setAutoShift(_ on: Bool) {
        guard shift != .locked else { return }
        let next: ShiftState = on ? .on : .off
        guard next != shift else { return }
        shift = next
        setNeedsDisplay()
    }

    // MARK: - drawing

    private func shifted(_ key: Key) -> String {
        key.isLetter && shift != .off ? key.output.uppercased() : key.output
    }

    private func label(_ key: Key) -> String {
        switch key.action {
        case .space: return "Özbekça"
        case .shift: return shift == .locked ? "⇪" : "⇧"
        default: return key.isLetter && shift != .off ? key.label.uppercased() : key.label
        }
    }

    private func options(_ key: Key) -> [String] {
        ([shifted(key)] + key.alternates).map {
            key.isLetter && shift != .off ? $0.uppercased() : $0
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(Theme.background.cgColor)
        context.fill(rect)

        let letterSize = rowHeight * 0.46
        let wordSize = rowHeight * 0.30

        for (index, p) in placed.enumerated() {
            let fill: UIColor
            if index == pressedIndex {
                fill = Theme.keyPressed
            } else if p.key.action == .enter
                || (p.key.action == .shift && shift != .off) {
                fill = Theme.keyAccent
            } else if p.key.action == .output || p.key.action == .space {
                fill = Theme.key
            } else {
                fill = Theme.keySpecial
            }
            let path = UIBezierPath(roundedRect: p.rect, cornerRadius: radius)
            fill.setFill()
            path.fill()

            let text = label(p.key)
            if !text.isEmpty {
                let isWord = text.count > 1 && p.key.action != .output
                let font = isWord
                    ? UIFont.systemFont(ofSize: wordSize)
                    : UIFont.systemFont(ofSize: letterSize, weight: p.key.isLetter ? .regular : .medium)
                draw(text, in: p.rect, font: font, colour: Theme.text)
            }

            if let hint = p.key.hint ?? p.key.alternates.first, p.key.isLetter {
                let corner = CGRect(
                    x: p.rect.maxX - 18, y: p.rect.minY + 2, width: 16, height: 14
                )
                draw(hint, in: corner, font: .systemFont(ofSize: rowHeight * 0.21), colour: Theme.hint)
            }
        }
    }

    private func draw(_ text: String, in rect: CGRect, font: UIFont, colour: UIColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colour]
        let size = (text as NSString).size(withAttributes: attributes)
        let origin = CGPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2
        )
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }

    // MARK: - touches

    private func index(at point: CGPoint) -> Int? {
        if let hit = placed.firstIndex(where: { $0.rect.contains(point) }) { return hit }
        // Fall back to the nearest key so that the gaps between keys are not dead space.
        return placed.enumerated().min { a, b in
            distance(a.element.rect, point) < distance(b.element.rect, point)
        }.flatMap { distance($0.element.rect, point) < gapY * 2 ? $0.offset : nil }
    }

    private func distance(_ rect: CGRect, _ point: CGPoint) -> CGFloat {
        let dx = max(0, max(rect.minX - point.x, point.x - rect.maxX))
        let dy = max(0, max(rect.minY - point.y, point.y - rect.maxY))
        return dx * dx + dy * dy
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let hit = index(at: point) else { return }
        pressedIndex = hit
        setNeedsDisplay()
        UIDevice.current.playInputClick()

        let key = placed[hit].key
        if key.action == .delete {
            delegate?.keyboardDidDelete(self)
            deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
                    self.delegate?.keyboardDidDelete(self)
                }
            }
        } else if !key.alternates.isEmpty {
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.32, repeats: false) { [weak self] _ in
                self?.showAlternates()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        if let strip = alternates {
            strip.select(at: convert(point, to: strip))
            return
        }
        let hit = index(at: point)
        guard hit != pressedIndex else { return }
        cancelTimers()
        pressedIndex = hit
        setNeedsDisplay()
        if let hit, !placed[hit].key.alternates.isEmpty {
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.32, repeats: false) { [weak self] _ in
                self?.showAlternates()
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let hit = pressedIndex
        cancelTimers()
        if let strip = alternates {
            if let chosen = strip.selected { emit(chosen) }
            strip.removeFromSuperview()
            alternates = nil
        } else if let hit {
            release(placed[hit].key)
        }
        pressedIndex = nil
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelTimers()
        alternates?.removeFromSuperview()
        alternates = nil
        pressedIndex = nil
        setNeedsDisplay()
    }

    private func cancelTimers() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        deleteTimer?.invalidate()
        deleteTimer = nil
    }

    private func showAlternates() {
        guard let hit = pressedIndex else { return }
        let p = placed[hit]
        guard !p.key.alternates.isEmpty else { return }
        let strip = AlternatesView(options: options(p.key))
        let size = strip.preferredSize
        var x = p.rect.midX - size.width / CGFloat(strip.options.count) / 2 - strip.padding
        x = min(max(0, x), bounds.width - size.width)
        strip.frame = CGRect(x: x, y: p.rect.minY - size.height, width: size.width, height: size.height)
        addSubview(strip)
        alternates = strip
    }

    private func emit(_ text: String) {
        delegate?.keyboard(self, didProduce: text)
        if shift == .on {
            shift = .off
            setNeedsDisplay()
        }
    }

    private func release(_ key: Key) {
        switch key.action {
        case .output: emit(shifted(key))
        case .space: emit(" ")
        case .enter: delegate?.keyboardDidReturn(self)
        case .delete: break // already handled when the touch began
        case .nextKeyboard: delegate?.keyboardDidRequestNextKeyboard(self)
        case .switchPage: if let target = key.pageTarget { setPage(target) }
        case .shift:
            let now = Date.timeIntervalSinceReferenceDate
            if now - lastShiftTap < 0.3 {
                shift = .locked
            } else {
                shift = shift == .off ? .on : .off
            }
            lastShiftTap = now
            setNeedsDisplay()
        }
    }
}
