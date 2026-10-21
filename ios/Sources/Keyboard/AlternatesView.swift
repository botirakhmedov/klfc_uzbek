import UIKit

/// The row of alternates shown while a key is held down. The finger stays on the screen,
/// slides sideways to pick one and lifting commits it, so this view only tracks a point;
/// it never handles touches itself.
final class AlternatesView: UIView {

    let options: [String]
    let padding: CGFloat = 4
    private let cellWidth: CGFloat = 44
    private let cellHeight: CGFloat = 52
    private var selectedIndex = 0

    var selected: String? { options.indices.contains(selectedIndex) ? options[selectedIndex] : nil }

    var preferredSize: CGSize {
        CGSize(
            width: CGFloat(options.count) * cellWidth + padding * 2,
            height: cellHeight + padding * 2
        )
    }

    init(options: [String]) {
        self.options = options
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// `point` is in this view's own coordinate space.
    func select(at point: CGPoint) {
        let index = Int((point.x - padding) / cellWidth)
        let clamped = min(max(0, index), options.count - 1)
        guard clamped != selectedIndex else { return }
        selectedIndex = clamped
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        UIBezierPath(roundedRect: bounds, cornerRadius: 8).addClip()
        Theme.popup.setFill()
        UIBezierPath(roundedRect: bounds, cornerRadius: 8).fill()

        for (index, option) in options.enumerated() {
            let cell = CGRect(
                x: padding + CGFloat(index) * cellWidth, y: padding,
                width: cellWidth, height: cellHeight
            )
            if index == selectedIndex {
                Theme.keyAccent.setFill()
                UIBezierPath(roundedRect: cell, cornerRadius: 8).fill()
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22),
                .foregroundColor: Theme.text,
            ]
            let size = (option as NSString).size(withAttributes: attributes)
            (option as NSString).draw(
                at: CGPoint(x: cell.midX - size.width / 2, y: cell.midY - size.height / 2),
                withAttributes: attributes
            )
        }
    }
}
