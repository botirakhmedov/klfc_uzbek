import UIKit

/// A keyboard cannot switch itself on, so the app is the one instruction the user needs
/// and a field to try the result in.
final class SetupViewController: UIViewController {

    private let field = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let title = UILabel()
        title.text = "Yangi alifbo klaviaturasi"
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.numberOfLines = 0

        let body = UILabel()
        body.text = """
            Ş, Ç, Ö va Ğ — alohida tugmalarda. Tutuq belgisi (ʼ) pastki qatorda turadi. \
            w yoki c kerak bölsa, ş va ç ni bosib turing.
            """
        body.font = .systemFont(ofSize: 15)
        body.textColor = .secondaryLabel
        body.numberOfLines = 0

        let steps = UILabel()
        steps.text = """
            Yoqiş uçun:
            Sozlamalar → Umumiy → Klaviatura → Klaviaturalar → \
            Yangi klaviatura qöşiş → Özbek klaviaturasi.
            """
        steps.font = .systemFont(ofSize: 15)
        steps.numberOfLines = 0

        let button = UIButton(type: .system)
        button.setTitle("Sozlamalarni oçiş", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        let tryLabel = UILabel()
        tryLabel.text = "Sinab köring"
        tryLabel.font = .systemFont(ofSize: 15)
        tryLabel.textColor = .secondaryLabel

        field.font = .systemFont(ofSize: 18)
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.separator.cgColor
        field.layer.cornerRadius = 8
        field.accessibilityIdentifier = "tryField"
        field.heightAnchor.constraint(equalToConstant: 120).isActive = true

        let stack = UIStackView(arrangedSubviews: [title, body, steps, button, tryLabel, field])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(8, after: title)
        stack.setCustomSpacing(28, after: button)
        stack.setCustomSpacing(8, after: tryLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        field.becomeFirstResponder()
    }

    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
