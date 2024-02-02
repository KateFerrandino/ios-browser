// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import Foundation
import Shared

struct ButtonToastViewModel {
    var labelText: String
    var descriptionText: String?
    var imageName: String?
    var buttonText: String?
    var textAlignment: NSTextAlignment = .left
}

class ButtonToast: Toast {
    struct UX {
        static let delay = DispatchTimeInterval.milliseconds(900)
        // Ecosia: Adjust Padding
        // static let padding: CGFloat = 15
        static let padding: CGFloat = 8
        // Ecosia: Adjust Padding
        // static let buttonPadding: CGFloat = 10
        static let buttonPadding: CGFloat = 16
        static let buttonBorderRadius: CGFloat = 5
        static let buttonBorderWidth: CGFloat = 1
        static let titleFontSize: CGFloat = 15
        static let descriptionFontSize: CGFloat = 13
        static let widthOffset: CGFloat = 20
        // Ecosia: Add properties
        static let standardCornerRadius: CGFloat = 10
    }

    // MARK: - UI
    private var horizontalStackView: UIStackView = .build { stackView in
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = UX.padding
        // Ecosia: Adjust properties
        stackView.distribution = .fill
        stackView.spacing = 8
        stackView.layer.cornerRadius = UX.standardCornerRadius
        
    }

    private var imageView: UIImageView = .build { imageView in
        // Ecosia: Add imageview properties
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.legacyTheme.ecosia.toastImageTint
        imageView.setContentHuggingPriority(.required, for: .horizontal)
    }

    private var labelStackView: UIStackView = .build { stackView in
        stackView.axis = .vertical
        // Ecosia: Review ToastView to look like v104
        // stackView.alignment = .fill
        stackView.alignment = .leading
        stackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private var titleLabel: UILabel = .build { label in
        label.font = DefaultDynamicFontHelper.preferredBoldFont(withTextStyle: .body,
                                                                size: UX.titleFontSize)
        label.numberOfLines = 0
        // Ecosia: Review ToastView to look like v104
        label.adjustsFontForContentSizeCategory = true
        label.lineBreakMode = .byTruncatingTail
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private var descriptionLabel: UILabel = .build { label in
        label.font = DefaultDynamicFontHelper.preferredBoldFont(withTextStyle: .body,
                                                                size: UX.descriptionFontSize)
        label.numberOfLines = 0
    }

    private var roundedButton: UIButton = .build { button in
        /* Ecosia: Review ToastView to look like v104
        button.layer.cornerRadius = UX.buttonBorderRadius
        button.layer.borderWidth = UX.buttonBorderWidth
        button.titleLabel?.font = DefaultDynamicFontHelper.preferredFont(withTextStyle: .body,
                                                                          size: Toast.UX.fontSize)
         */
        button.titleLabel?.font = DefaultDynamicFontHelper.preferredFont(withTextStyle: .body,
                                                                         size: Toast.UX.fontSize).bold()
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byClipping
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.1
    }

    // Pass themeManager to call on init
    init(viewModel: ButtonToastViewModel,
         theme: Theme?,
         completion: ((_ buttonPressed: Bool) -> Void)? = nil) {
        super.init(frame: .zero)

        self.completionHandler = completion

        self.clipsToBounds = true
        let createdToastView = createView(viewModel: viewModel)
        self.addSubview(createdToastView)

        NSLayoutConstraint.activate([
            toastView.leadingAnchor.constraint(equalTo: leadingAnchor),
            toastView.trailingAnchor.constraint(equalTo: trailingAnchor),
            toastView.heightAnchor.constraint(equalTo: heightAnchor),

            heightAnchor.constraint(greaterThanOrEqualToConstant: Toast.UX.toastHeight)
        ])

        animationConstraint = toastView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor,
                                                             constant: Toast.UX.toastHeight)
        animationConstraint?.isActive = true
        if let theme = theme {
            applyTheme(theme: theme)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createView(viewModel: ButtonToastViewModel) -> UIView {
        if let imageName = viewModel.imageName {
            imageView = UIImageView(image: UIImage.templateImageNamed(imageName))
            // Ecosia: Add image tintColor
            imageView.tintColor = UIColor.legacyTheme.ecosia.toastImageTint
            // Ecosia: Review ToastView to look like v104
            let space = UIView()
            space.widthAnchor.constraint(equalToConstant: UX.padding).isActive = true
            horizontalStackView.addArrangedSubview(space)
            horizontalStackView.addArrangedSubview(imageView)
        }

        titleLabel.textAlignment = viewModel.textAlignment
        titleLabel.text = viewModel.labelText

        labelStackView.addArrangedSubview(titleLabel)

        if let descriptionText = viewModel.descriptionText {
            titleLabel.lineBreakMode = .byClipping
            titleLabel.numberOfLines = 1 // if showing a description we cant wrap to the second line
            titleLabel.adjustsFontSizeToFitWidth = true

            descriptionLabel.textAlignment = viewModel.textAlignment
            descriptionLabel.text = descriptionText
            labelStackView.addArrangedSubview(descriptionLabel)
        }

        horizontalStackView.addArrangedSubview(labelStackView)
        setupPaddedButton(stackView: horizontalStackView, buttonText: viewModel.buttonText)
        toastView.addSubview(horizontalStackView)

        NSLayoutConstraint.activate([
            labelStackView.centerYAnchor.constraint(equalTo: horizontalStackView.centerYAnchor),

            /* Ecosia: Review constraints
            horizontalStackView.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: UX.padding),
            horizontalStackView.trailingAnchor.constraint(equalTo: toastView.trailingAnchor),
            horizontalStackView.bottomAnchor.constraint(equalTo: toastView.safeAreaLayoutGuide.bottomAnchor),
            horizontalStackView.topAnchor.constraint(equalTo: toastView.topAnchor),
            horizontalStackView.heightAnchor.constraint(equalToConstant: Toast.UX.toastHeight),
             */
            horizontalStackView.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: Toast.UX.toastOffset),
            horizontalStackView.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -Toast.UX.toastOffset),
            horizontalStackView.bottomAnchor.constraint(equalTo: toastView.safeAreaLayoutGuide.bottomAnchor, constant: -Toast.UX.toastOffset),
            horizontalStackView.topAnchor.constraint(equalTo: toastView.topAnchor),
            horizontalStackView.heightAnchor.constraint(equalToConstant: Toast.UX.toastHeight - Toast.UX.toastOffset),
        ])
        
        // Ecosia: Review ToastView to look like v104
        toastView.layer.cornerRadius = UX.standardCornerRadius
        toastView.layer.masksToBounds = true

        return toastView
    }

    func setupPaddedButton(stackView: UIStackView, buttonText: String?) {
        guard let buttonText = buttonText else { return }
        /* Ecosia: Review ToastView to look like v104
        let paddedView = UIView()
        paddedView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(paddedView)
         */
        roundedButton.setTitle(buttonText, for: [])
        // Ecosia: Review ToastView to look like v104
        // paddedView.addSubview(roundedButton)
        stackView.addArrangedSubview(roundedButton)

        NSLayoutConstraint.activate([
            /* Ecosia: Review ToastView to look like v104
            roundedButton.heightAnchor.constraint(
                equalToConstant: roundedButton.titleLabel!.intrinsicContentSize.height + 2 * UX.buttonPadding),
            roundedButton.widthAnchor.constraint(
                equalToConstant: roundedButton.titleLabel!.intrinsicContentSize.width + 2 * UX.buttonPadding),
            roundedButton.centerYAnchor.constraint(equalTo: paddedView.centerYAnchor),
            roundedButton.centerXAnchor.constraint(equalTo: paddedView.centerXAnchor),

            paddedView.topAnchor.constraint(equalTo: stackView.topAnchor),
            paddedView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor),
            paddedView.widthAnchor.constraint(equalTo: roundedButton.widthAnchor, constant: UX.widthOffset)
             */
            roundedButton.widthAnchor.constraint(
                equalToConstant: roundedButton.titleLabel!.intrinsicContentSize.width + 2 * UX.buttonPadding),
        ])

        // Ecosia: Review ToastView to look like v104
        // roundedButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(buttonPressed)))
        // paddedView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(buttonPressed)))
        roundedButton.addTarget(self, action: #selector(buttonPressed), for: .primaryActionTriggered)
    }

    override func applyTheme(theme: Theme) {
        super.applyTheme(theme: theme)

        titleLabel.textColor = theme.colors.textInverted
        descriptionLabel.textColor = theme.colors.textInverted
        imageView.tintColor = theme.colors.textInverted
        roundedButton.setTitleColor(theme.colors.textInverted, for: [])
        /* Ecosia: Add `horizontalStackView` background as the Toast view is made clear
           so to have the padding effect from bottom, left and right
         */
        horizontalStackView.backgroundColor = UIColor.legacyTheme.ecosia.quarternaryBackground
        // Ecosia: Review ToastView to look like v104
        // roundedButton.layer.borderColor = theme.colors.borderInverted.cgColor
    }

    // MARK: - Button action
    @objc
    func buttonPressed() {
        completionHandler?(true)
        dismiss(true)
    }
}
