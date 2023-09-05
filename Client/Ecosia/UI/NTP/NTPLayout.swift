/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Shared

protocol NTPLayoutHighlightDataSource: AnyObject {
    func ntpLayoutHighlightText() -> String?
    func getSectionViewModel(shownSection: Int) -> HomepageViewModelProtocol?
}

class NTPLayout: UICollectionViewCompositionalLayout {
    weak var highlightDataSource: NTPLayoutHighlightDataSource?

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attr = super.layoutAttributesForElements(in: rect) else { return nil}

        guard let impact = attr.first(where: {
            $0.representedElementCategory == .cell && highlightDataSource?.getSectionViewModel(shownSection: $0.indexPath.section)?.sectionType == .impact
        }), let tooltip = attr.first(where: {
            $0.representedElementCategory == .supplementaryView &&
            highlightDataSource?.getSectionViewModel(shownSection: $0.indexPath.section)?.sectionType == .impact
        }) else { return attr }

        if let text = highlightDataSource?.ntpLayoutHighlightText() {
            let font = UIFont.preferredFont(forTextStyle: .callout)
            let width = impact.bounds.width - 4 * NTPTooltip.margin
            let height = text.height(constrainedTo: width, using: font) + 2 * NTPTooltip.containerMargin + NTPTooltip.margin

            tooltip.frame = impact.frame
            tooltip.frame.size.height = height
            tooltip.frame.origin.y -= (height)
            tooltip.alpha = 1
        } else {
            tooltip.alpha = 0
        }
        return attr
    }
}

extension String {
    fileprivate func height(constrainedTo width: CGFloat, using font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [NSAttributedString.Key.font: font], context: nil)
        return boundingBox.height
    }
}
