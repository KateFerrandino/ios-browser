// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Core

protocol NTPAboutEcosiaCellDelegate: AnyObject {
    func invalidateLayout(at indexPath: IndexPath)
}

class NTPAboutEcosiaCellViewModel {
    private var sections = AboutEcosiaSection.allCases
    
    weak var delegate: NTPAboutEcosiaCellDelegate?
    var expandedIndex: IndexPath?
}

extension NTPAboutEcosiaCellViewModel: HomepageViewModelProtocol {
    var isEnabled: Bool {
        User.shared.showAboutEcosia
    }
    
    var sectionType: HomepageSectionType {
        .aboutEcosia
    }
    
    var headerViewModel: LabelButtonHeaderViewModel {
        .init(title: .localized(.aboutEcosia),
              isButtonHidden: true)
    }
    
    func section(for traitCollection: UITraitCollection) -> NSCollectionLayoutSection {
        let height = NTPAboutEcosiaCell.UX.height
        let count = CGFloat(numberOfItemsInSection())
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1),
                              heightDimension: .estimated(height))
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1),
                              heightDimension: .estimated(height*count)),
            subitem: item,
            count: 1
        )
        let section = NSCollectionLayoutSection(group: group)
        let insets = sectionType.sectionInsets(traitCollection)
        section.contentInsets = .init(top: insets, leading: insets, bottom: insets, trailing: insets)
        section.boundarySupplementaryItems = [
            .init(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                    heightDimension: .estimated(100)),
                  elementKind: UICollectionView.elementKindSectionHeader,
                  alignment: .top)
        ]
        return section
    }
    
    func numberOfItemsInSection() -> Int {
        sections.count
    }
}

extension NTPAboutEcosiaCellViewModel: HomepageSectionHandler {
    
    func configure(_ cell: UICollectionViewCell, at indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = cell as? NTPAboutEcosiaCell else {
            return UICollectionViewCell()
        }
        cell.configure(section: sections[indexPath.row], viewModel: self)
        return cell
    }
    
    func didSelectItem(at indexPath: IndexPath, homePanelDelegate: HomePanelDelegate?, libraryPanelDelegate: LibraryPanelDelegate?) {
        if let previousIndex = expandedIndex {
            delegate?.invalidateLayout(at: previousIndex)
        }
        
        expandedIndex = indexPath
        delegate?.invalidateLayout(at: indexPath)
    }
}