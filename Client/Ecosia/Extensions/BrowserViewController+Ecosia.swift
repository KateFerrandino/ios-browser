/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Core
import Shared

extension BrowserViewController: HomepageViewControllerDelegate {
    func homeDidTapSearchButton(_ home: HomepageViewController) {
        urlBar.tabLocationViewDidTapLocation(self.urlBar.locationView)
    }
}

extension BrowserViewController: APNConsentViewDelegate {
    func apnConsentViewDidShow(_ viewController: APNConsentViewController) {
        User.shared.markAPNConsentScreenAsShown()
    }
}

extension BrowserViewController: DefaultBrowserDelegate {
    @available(iOS 14, *)
    func defaultBrowserDidShow(_ defaultBrowser: DefaultBrowser) {
        profile.prefs.setInt(1, forKey: PrefsKeys.IntroSeen)
//        homepageViewController?.reloadTooltip()
    }
}

extension BrowserViewController: SettingsDelegate {
    func settingsOpenURLInNewTab(_ url: URL) {
        
    }
    
    func didFinish() {
        
    }
    
    func reloadHomepage() {
        
    }
}

extension BrowserViewController: WhatsNewViewDelegate {
    func whatsNewViewDidShow(_ viewController: WhatsNewViewController) {
        whatsNewDataProvider.markPreviousVersionsAsSeen()
//        homepageViewController?.reloadTooltip()
    }
}

extension BrowserViewController: PageActionsShortcutsDelegate {
    func pageOptionsOpenHome() {
        tabToolbarDidPressHome(toolbar, button: .init())
        dismiss(animated: true)
        Analytics.shared.menuClick("home")
    }

    func pageOptionsNewTab() {
        openBlankNewTab(focusLocationField: false)
        dismiss(animated: true)
        Analytics.shared.menuClick("new_tab")
    }
    
    func pageOptionsSettings() {
        let settingsTableViewController = AppSettingsTableViewController(
            with: self.profile,
            and: self.tabManager,
            delegate: self)

        let controller = ThemedNavigationController(rootViewController: settingsTableViewController)
        // On iPhone iOS13 the WKWebview crashes while presenting file picker if its not full screen. Ref #6232
        if UIDevice.current.userInterfaceIdiom == .phone {
            controller.modalPresentationStyle = .fullScreen
        }
        Analytics.shared.menuClick("settings")

        // Wait to present VC in an async dispatch queue to prevent a case where dismissal
        // of this popover on iPad seems to block the presentation of the modal VC.
        DispatchQueue.main.async { [weak self] in
            self?.showViewController(viewController: controller)
        }
    }

    func pageOptionsShare() {
        dismiss(animated: true) {
            guard let item = self.menuHelper?.getSharingAction().items.first,
                  let handler = item.tapHandler else { return }
            handler(item)
        }
    }
}

extension BrowserViewController {
    
    func presentIntroViewController(_ alwaysShow: Bool = false) {
        if showLoadingScreen(for: .shared) {
            presentLoadingScreen()
        } else if User.shared.firstTime {
            handleFirstTimeUserActions()
        } else {
            presentInsightfulSheetsIfNeeded()
        }
    }
    
    private func presentLoadingScreen() {
        present(LoadingScreen(profile: profile, referrals: referrals, referralCode: User.shared.referrals.pendingClaim), animated: true)
    }
    
    private func handleFirstTimeUserActions() {
        User.shared.firstTime = false
        User.shared.migrated = true
        User.shared.hideBookmarksNewBadge()
        User.shared.hideBookmarksImportExportTooltip()
        toolbarContextHintVC.deactivateHintForNewUsers()
    }
    
    private func showLoadingScreen(for user: User) -> Bool {
        (user.migrated != true && !user.firstTime)
        || user.referrals.pendingClaim != nil
    }
    
    func presentInsightfulSheetsIfNeeded() {
        guard isHomePage(),
              presentedViewController == nil,
              !showLoadingScreen(for: .shared) else { return }
        
        if !presentDefaultBrowserPromoIfNeeded() {
            presentWhatsNewPageIfNeeded()
        }
    }
    
    private func isHomePage() -> Bool {
        tabManager.selectedTab?.url.flatMap { InternalURL($0)?.isAboutHomeURL } ?? false
    }
    
    @discardableResult
    private func presentWhatsNewPageIfNeeded() -> Bool {
        guard shouldShowWhatsNewPageScreen else { return false }
        
        let viewModel = WhatsNewViewModel(provider: whatsNewDataProvider)
        WhatsNewViewController.presentOn(self, viewModel: viewModel)
        return true
    }
    
    @discardableResult
    private func presentDefaultBrowserPromoIfNeeded() -> Bool {
        guard shouldShowDefaultBrowserPromo,
              DefaultBrowserExperiment.minPromoSearches() <= User.shared.searchCount else { return false }
        
        if #available(iOS 14, *) {
            let defaultPromo = DefaultBrowser(delegate: self)
            present(defaultPromo, animated: true)
        } else {
            profile.prefs.setInt(1, forKey: PrefsKeys.IntroSeen)
        }
        return true
    }
}
