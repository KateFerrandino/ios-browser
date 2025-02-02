// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit
import Shared
import Core

enum AppSettingsDeeplinkOption {
    case contentBlocker
    case customizeHomepage
    case customizeTabs
    case customizeToolbar
    case customizeTopSites
    case wallpaper
}

/// App Settings Screen (triggered by tapping the 'Gear' in the Tab Tray Controller)
class AppSettingsTableViewController: SettingsTableViewController, FeatureFlaggable {

    // MARK: - Properties
    var deeplinkTo: AppSettingsDeeplinkOption?

    // MARK: - Initializers
    init(with profile: Profile,
         and tabManager: TabManager,
         delegate: SettingsDelegate?,
         deeplinkingTo destination: AppSettingsDeeplinkOption? = nil) {
        self.deeplinkTo = destination

        super.init(style: .insetGrouped)
        self.profile = profile
        self.tabManager = tabManager
        self.settingsDelegate = delegate
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View lifecycles
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = String.AppSettingsTitle
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: .AppSettingsDone,
            style: .done,
            target: navigationController,
            action: #selector((navigationController as! ThemedNavigationController).done))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "AppSettingsTableViewController.navigationItem.leftBarButtonItem"

        tableView.accessibilityIdentifier = "AppSettingsTableViewController.tableView"

        // Refresh the user's FxA profile upon viewing settings. This will update their avatar,
        // display name, etc.
        //// profile.rustAccount.refreshProfile()

        checkForDeeplinkSetting()
    }

    private func checkForDeeplinkSetting() {
        guard let deeplink = deeplinkTo else { return }
        var viewController: SettingsTableViewController

        switch deeplink {
        case .contentBlocker:
            viewController = ContentBlockerSettingViewController(prefs: profile.prefs)
            viewController.tabManager = tabManager

        case .customizeHomepage:
            // Ecosia: Custom ntp customization settings
            viewController = NTPCustomizationSettingsViewController()

        case .customizeTabs:
            viewController = TabsSettingsViewController()

        case .customizeToolbar:
            let viewModel = SearchBarSettingsViewModel(prefs: profile.prefs)
            viewController = SearchBarSettingsViewController(viewModel: viewModel)

        case .wallpaper:
            let viewModel = LegacyWallpaperSettingsViewModel(with: tabManager, and: LegacyWallpaperManager())
            let wallpaperVC = LegacyWallpaperSettingsViewController(with: viewModel)
            // Push wallpaper settings view controller directly as its not of type settings viewcontroller
            navigationController?.pushViewController(wallpaperVC, animated: true)
            return

        case .customizeTopSites:
            viewController = TopSitesSettingsViewController()
        }

        viewController.profile = profile
        // Ecosia: forward delegate to deeplink page
        viewController.settingsDelegate = settingsDelegate
        navigationController?.pushViewController(viewController, animated: false)
        // Add a done button from this view
        viewController.navigationItem.rightBarButtonItem = navigationItem.rightBarButtonItem
    }

    override func generateSettings() -> [SettingSection] {
        var settings = [SettingSection]()

        let prefs = profile.prefs
        var generalSettings: [Setting] = [
            OpenWithSetting(settings: self),
            ThemeSetting(settings: self),
            SiriPageSetting(settings: self),
            BoolSetting(
                prefs: prefs,
                prefKey: PrefsKeys.KeyBlockPopups,
                defaultValue: true,
                titleText: .AppSettingsBlockPopups),
            NoImageModeSetting(settings: self)
           ]

        let tabTrayGroupsAreBuildActive = featureFlags.isFeatureEnabled(.tabTrayGroups, checking: .buildOnly)
        let inactiveTabsAreBuildActive = featureFlags.isFeatureEnabled(.inactiveTabs, checking: .buildOnly)

        /* Ecosia: deactivate china settings
        let accountChinaSyncSetting: [Setting]
        if !AppInfo.isChinaEdition {
            accountChinaSyncSetting = []
        } else {
            accountChinaSyncSetting = [
                // Show China sync service setting:
                ChinaSyncServiceSetting(settings: self)
            ]
        }
        */
        // There is nothing to show in the Customize section if we don't include the compact tab layout
        // setting on iPad. When more options are added that work on both device types, this logic can
        // be changed.
        
        generalSettings += [
            BoolSetting(
                prefs: prefs,
                prefKey: "showClipboardBar",
                defaultValue: false,
                titleText: .SettingsOfferClipboardBarTitle,
                statusText: .SettingsOfferClipboardBarStatus),
            BoolSetting(
                prefs: prefs,
                prefKey: PrefsKeys.ContextMenuShowLinkPreviews,
                defaultValue: true,
                titleText: .SettingsShowLinkPreviewsTitle,
                statusText: .SettingsShowLinkPreviewsStatus)
        ]

        if #available(iOS 14.0, *) {
            settings += [
                SettingSection(footerTitle: .init(string: .localized(.linksFromWebsites)), children: [DefaultBrowserSetting()])
            ]
        }
        /* Ecosia: Deactivate account settings
        let accountSectionTitle = NSAttributedString(string: .FxAFirefoxAccount)

        let footerText = !profile.hasAccount() ? NSAttributedString(string: .Settings.Sync.ButtonDescription) : nil
        settings += [
            SettingSection(title: accountSectionTitle, footerTitle: footerText, children: [
                // Without a Firefox Account:
                ConnectSetting(settings: self),
                AdvancedAccountSetting(settings: self),
                // With a Firefox Account:
                AccountStatusSetting(settings: self),
                SyncNowSetting(settings: self)
            ] + accountChinaSyncSetting )]
         */

        var searchSettings: [Setting] = [
            SearchAreaSetting(settings: self),
            SafeSearchSettings(settings: self),
            AutoCompleteSettings(prefs: prefs),
            PersonalSearchSettings(prefs: prefs)
        ]
        
        // Ecosia: Quick Search Shortcuts Experiment
        if EngineShortcutsExperiment.isEnabled {
            searchSettings.insert(QuickSearchSearchSetting(settings: self), at: 2)
        }
                
        // Ecosia: Custom homepage settings
        let homepageSettings = HomepageSettings(settings: self)
        homepageSettings.delegate = settingsDelegate
        var customization: [Setting] = [homepageSettings]
        
        if tabTrayGroupsAreBuildActive || inactiveTabsAreBuildActive {
            customization += [TabsSetting()]
        }
        
        if SearchBarSettingsViewModel.isEnabled {
            customization += [SearchBarSetting(settings: self)]
        }
        
        settings += [.init(title: .init(string: .localized(.search)), children: searchSettings),
                     .init(title: .init(string: .localized(.customization)), children: customization),
                     .init(title: .init(string: .SettingsGeneralSectionTitle), children: generalSettings)]
        
        var privacySettings = [Setting]()
        privacySettings.append(LoginsSetting(settings: self, delegate: settingsDelegate))

        privacySettings.append(ClearPrivateDataSetting(settings: self))

        privacySettings.append(EcosiaSendAnonymousUsageDataSetting(prefs: prefs))
        
        privacySettings += [
            BoolSetting(prefs: prefs,
                prefKey: "settings.closePrivateTabs",
                defaultValue: false,
                titleText: .AppSettingsClosePrivateTabsTitle,
                statusText: .AppSettingsClosePrivateTabsDescription)
        ]

        privacySettings.append(ContentBlockerSetting(settings: self))

        privacySettings += [
            EcosiaPrivacyPolicySetting(),
            EcosiaTermsSetting()
        ]

        settings += [
            SettingSection(title: NSAttributedString(string: .AppSettingsPrivacyTitle), children: privacySettings),
            SettingSection(title: NSAttributedString(string: .AppSettingsSupport), children: [
                // Ecosia: ShowIntroductionSetting(settings: self),
                EcosiaSendFeedbackSetting(),
                // Ecosia: SendAnonymousUsageDataSetting(prefs: prefs, delegate: settingsDelegate)
                // Ecosia: StudiesToggleSetting(prefs: prefs, delegate: settingsDelegate),
                // Ecosia: OpenSupportPageSetting(delegate: settingsDelegate),
            ]),
            SettingSection(title: NSAttributedString(string: .AppSettingsAbout), children: [
                AppStoreReviewSetting(),
                VersionSetting(settings: self),
                LicenseAndAcknowledgementsSetting(),
                /* Ecosia: deactivate MOZ debug settings
				YourRightsSetting(),
                ExportBrowserDataSetting(settings: self),
                ExportLogDataSetting(settings: self),
                DeleteExportedDataSetting(settings: self),
                ForceCrashSetting(settings: self),
                SlowTheDatabase(settings: self),
                ForgetSyncAuthStateDebugSetting(settings: self),
                SentryIDSetting(settings: self),
                ChangeToChinaSetting(settings: self),
                ShowEtpCoverSheet(settings: self),
                TogglePullToRefresh(settings: self),
                ToggleInactiveTabs(settings: self),
                ToggleHistoryGroups(settings: self),
                ResetContextualHints(settings: self),
                OpenFiftyTabsDebugOption(settings: self),
                ExperimentsSettings(settings: self)
 */
                // Hidden Debug Settings
                PushBackInstallation(settings: self),
                ToggleImpactIntro(settings: self),
                ShowTour(settings: self),
                CreateReferralCode(settings: self),
                AddReferral(settings: self),
                AddClaim(settings: self),
                InactiveTabsExpireEarly(settings: self),
                ChangeSearchCount(settings: self),
                ResetSearchCount(settings: self),
                UnleashDefaultBrowserSetting(settings: self),
                EngagementServiceIdentifierSetting(settings: self)
            ])]

        return settings
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = super.tableView(tableView, viewForHeaderInSection: section) as! ThemedTableSectionHeaderFooterView
        return headerView
    }
}
