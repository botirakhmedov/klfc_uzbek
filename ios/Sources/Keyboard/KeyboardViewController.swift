import UIKit

/// The keyboard extension: it owns the board and writes into whatever field has focus.
final class KeyboardViewController: UIInputViewController {

    private var board: KeyboardLayoutView!
    private var heightConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()

        board = KeyboardLayoutView(frame: .zero)
        board.delegate = self
        board.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(board)

        // An extension gets no height by default; it has to ask for one.
        heightConstraint = view.heightAnchor.constraint(equalToConstant: board.preferredHeight)
        heightConstraint.priority = .required - 1
        NSLayoutConstraint.activate([
            heightConstraint,
            board.topAnchor.constraint(equalTo: view.topAnchor),
            board.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            board.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            board.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        board.reset()
        heightConstraint.constant = board.preferredHeight
        refreshAutoShift()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        refreshAutoShift()
    }

    private func refreshAutoShift() {
        let traits = textDocumentProxy
        guard traits.autocapitalizationType == .sentences else {
            board.setAutoShift(false)
            return
        }
        let before = traits.documentContextBeforeInput ?? ""
        let trimmed = before.trimmingCharacters(in: .whitespaces)
        board.setAutoShift(trimmed.isEmpty || trimmed.hasSuffix("."))
    }
}

extension KeyboardViewController: KeyboardLayoutViewDelegate {

    func keyboard(_ view: KeyboardLayoutView, didProduce text: String) {
        textDocumentProxy.insertText(text)
    }

    func keyboardDidDelete(_ view: KeyboardLayoutView) {
        textDocumentProxy.deleteBackward()
    }

    func keyboardDidReturn(_ view: KeyboardLayoutView) {
        textDocumentProxy.insertText("\n")
    }

    func keyboardDidRequestNextKeyboard(_ view: KeyboardLayoutView) {
        advanceToNextInputMode()
    }
}
