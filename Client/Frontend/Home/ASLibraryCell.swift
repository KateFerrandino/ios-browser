/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Shared
import SnapKit

class ASLibraryCell: UICollectionViewCell, Themeable {

    var mainView = UIStackView()
    weak var widthConstraint: NSLayoutConstraint!
    weak var heightConstraint: NSLayoutConstraint!

    struct LibraryPanel {
        let title: String
        let image: UIImage?
        let color: UIColor
    }

    var libraryButtons: [LibraryShortcutView] = []

    let bookmarks = LibraryPanel(title: Strings.AppMenuBookmarksTitleString, image: UIImage(named: "libraryFavorites"), color: UIColor.Photon.Yellow60)
    let history = LibraryPanel(title: Strings.AppMenuHistoryTitleString, image: UIImage(named: "libraryHistory"), color: UIColor.Photon.Teal60)
    let readingList = LibraryPanel(title: Strings.AppMenuReadingListTitleString, image: UIImage(named: "libraryReading"), color: UIColor.Photon.Blue60)
    let downloads = LibraryPanel(title: Strings.AppMenuDownloadsTitleString, image: UIImage(named: "libraryDownloads"), color: UIColor.Photon.Purple60)

    override init(frame: CGRect) {
        super.init(frame: frame)
        mainView.distribution = .fillEqually
        mainView.spacing = 0
        mainView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainView)

        mainView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }

        let widthConstraint = mainView.widthAnchor.constraint(equalToConstant: 100)
        widthConstraint.priority = .defaultHigh
        widthConstraint.isActive = true
        self.widthConstraint = widthConstraint

        let heightConstraint = mainView.heightAnchor.constraint(equalToConstant: 100)
        heightConstraint.priority = .defaultHigh
        heightConstraint.isActive = true
        self.heightConstraint = heightConstraint


        // Ecosia: Show history instead of synced tabs
        [bookmarks, history, readingList, downloads].forEach { item in
            let view = LibraryShortcutView()
            view.button.setImage(item.image, for: .normal)
            view.title.text = item.title
            let words = view.title.text?.components(separatedBy: NSCharacterSet.whitespacesAndNewlines).count
            view.title.numberOfLines = words == 1 ? 1 : 2
            // view.button.backgroundColor = item.color
            view.button.setTitleColor(UIColor.theme.ecosia.highContrastText, for: .normal)
            view.accessibilityLabel = item.title
            mainView.addArrangedSubview(view)
            libraryButtons.append(view)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        libraryButtons.forEach { button in
            button.title.textColor = UIColor.theme.ecosia.highContrastText
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        applyTheme()
    }
}
