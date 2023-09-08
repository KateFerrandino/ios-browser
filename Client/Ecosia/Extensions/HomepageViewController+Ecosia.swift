// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import UIKit
import Core

protocol HomepageViewControllerDelegate: AnyObject {
    func homeDidTapSearchButton(_ home: HomepageViewController)
    func homeDidPressPersonalCounter(_ home: HomepageViewController, completion: (() -> Void)?)
}

protocol SharedHomepageCellDelegate: AnyObject {
    func openLink(url: URL)
    func invalidateLayout(at indexPaths: [IndexPath])
}

extension HomepageViewController {
    func configureEcosiaSetup() {
        personalCounter.subscribe(self) { [weak self] _ in
            self?.viewModel.impactViewModel.refreshCells()
        }

        referrals.subscribe(self) { [weak self] _ in
            self?.viewModel.impactViewModel.refreshCells()
        }
    }
}

extension HomepageViewController: SharedHomepageCellDelegate {
    func openLink(url: URL) {
        homePanelDelegate?.homePanel(didSelectURL: url, visitType: .link, isGoogleTopSite: false)
    }
    
    func invalidateLayout(at indexPaths: [IndexPath]) {
        let context = UICollectionViewLayoutInvalidationContext()
        context.invalidateItems(at: indexPaths)
        collectionView.collectionViewLayout.invalidateLayout(with: context)
    }
}

extension HomepageViewController: NTPTooltipDelegate {
    func ntpTooltipTapped(_ tooltip: NTPTooltip?) {
        handleTooltipTapped(tooltip)
    }
    
    func ntpTooltipCloseTapped(_ tooltip: NTPTooltip?) {
        handleTooltipTapped(tooltip)
    }
    
    private func handleTooltipTapped(_ tooltip: NTPTooltip?) {
        guard let ntpHighlight = NTPTooltip.highlight(for: User.shared, isInPromoTest: DefaultBrowserExperiment.isInPromoTest()) else { return }

        UIView.animate(withDuration: 0.3) {
            tooltip?.alpha = 0
        } completion: { _ in

            switch ntpHighlight {
            case .counterIntro:
                User.shared.hideCounterIntro()
            case .gotClaimed, .successfulInvite:
                User.shared.referrals.accept()
            case .referralSpotlight:
                Analytics.shared.openInvitePromo()
                User.shared.hideReferralSpotlight()
            }
        }
    }

    func reloadTooltip() {
        reloadView()
    }
}

extension HomepageViewController: NTPLibraryDelegate {
    func libraryCellOpenBookmarks() {
        homePanelDelegate?.homePanelDidRequestToOpenLibrary(panel: .bookmarks)
    }

    func libraryCellOpenHistory() {
        homePanelDelegate?.homePanelDidRequestToOpenLibrary(panel: .history)
    }

    func libraryCellOpenReadlist() {
        homePanelDelegate?.homePanelDidRequestToOpenLibrary(panel: .readingList)
    }

    func libraryCellOpenDownloads() {
        homePanelDelegate?.homePanelDidRequestToOpenLibrary(panel: .downloads)
    }
}

extension HomepageViewController: NTPImpactCellDelegate {
    func impactCellButtonAction(info: ClimateImpactInfo) {
        switch info {
        case .personalCounter:
            let url = Environment.current.urlProvider.aboutCounter
            openLink(url: url)
        case .invites:
            let invite = MultiplyImpact(delegate: nil, referrals: referrals) // TODO: Update invite page
            let nav = EcosiaNavigation(rootViewController: invite)
            present(nav, animated: true)
        default:
            return
        }
    }
}

extension HomepageViewController: NTPNewsCellDelegate {
    func openSeeAllNews() {
        let news = NewsController(items: viewModel.newsViewModel.items)
        news.delegate = self
        let nav = EcosiaNavigation(rootViewController: news)
        present(nav, animated: true)
        Analytics.shared.navigation(.open, label: .news)
    }
}

extension HomepageViewController: NTPBookmarkNudgeCellDelegate {
    func nudgeCellOpenBookmarks() {
        homePanelDelegate?.homePanelDidRequestToOpenLibrary(panel: .bookmarks)
        User.shared.hideBookmarksNTPNudgeCard()
        reloadView()
    }
    
    func nudgeCellDismiss() {
        User.shared.hideBookmarksNTPNudgeCard()
        reloadView()
    }
}

extension HomepageViewController: NTPCustomizationCellDelegate {
    func openNTPCustomizationSettings() {
        // TODO: Is this the right place to get the profile?
        guard let profile = currentTab?.profile else { return }
        let settingsPage = NTPCustomizationSettingsViewController(profile: profile)
        settingsPage.ntpDataModelDelegate = viewModel
        let navigation = EcosiaNavigation(rootViewController: settingsPage)
        present(navigation, animated: true)
    }
}
