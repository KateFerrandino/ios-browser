/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

class AddNewTabButton: ToolbarButton {
    struct Config {
        let hideCircle: Bool
        let margin: CGFloat

        static var standard: Config {
            return .init(hideCircle: false, margin: 8)
        }
    }

    let circle = UIView()
    var config: Config = .standard

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    convenience init(config: Config) {
        self.init(frame: .zero)
        self.config = config
    }

    private func setup() {
        setImage(UIImage(named: "nav-add"), for: .normal)
        circle.isUserInteractionEnabled = false
        addSubview(circle)
        sendSubviewToBack(circle)
        applyTheme()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let height = bounds.height - config.margin
        circle.bounds = .init(size: .init(width: height, height: height))
        circle.layer.cornerRadius = circle.bounds.height / 2
        circle.center = .init(x: bounds.width/2, y: bounds.height/2)
        circle.isHidden = config.hideCircle
    }

    override func applyTheme() {
        circle.backgroundColor = UIColor.theme.ecosia.tertiaryBackground
        tintColor = UIColor.theme.ecosia.primaryButton
        selectedTintColor = UIColor.theme.ecosia.primaryButtonActive
        unselectedTintColor = UIColor.theme.ecosia.primaryButton
    }
}