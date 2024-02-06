// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

class OpenFiftyTabsDebugOption: HiddenSetting {
    override var accessibilityIdentifier: String? { return "OpenFiftyTabsOption.Setting" }

    override var title: NSAttributedString? {
        /* Ecosia: Update Debug message
        return NSAttributedString(string: "Open 50 `mozilla.org` tabs ⚠️", attributes: [NSAttributedString.Key.foregroundColor: theme.colors.textPrimary])
         */
        return NSAttributedString(string: "Open 50 `ecosia.org` tabs ⚠️", attributes: [NSAttributedString.Key.foregroundColor: theme.colors.textPrimary])

    }

    override func onClick(_ navigationController: UINavigationController?) {
        // Ecosia: Update URL
        // guard let url = URL(string: "https://www.mozilla.org") else { return }
        guard let url = URL(string: "https://www.ecosia.org") else { return }
        let object = OpenTabNotificationObject(type: .debugOption(50, url))
        NotificationCenter.default.post(name: .OpenTabNotification, object: object)
    }
}
