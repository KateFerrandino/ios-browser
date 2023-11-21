// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Common
import MozillaAppServices
import Shared

protocol HomepageViewModelDelegate: AnyObject {
    func reloadView()
}

protocol HomepageDataModelDelegate: AnyObject {
    func reloadView()
}

class HomepageViewModel: FeatureFlaggable {
    struct UX {
        static let spacingBetweenSections: CGFloat = 62
        static let standardInset: CGFloat = 18
        static let iPadInset: CGFloat = 50
        static let iPadTopSiteInset: CGFloat = 25

        // Shadow
        static let shadowRadius: CGFloat = 4
        static let shadowOffset = CGSize(width: 0, height: 2)
        static let shadowOpacity: Float = 1 // shadow opacity set to 0.16 through shadowDefault themed color

        // General
        static let generalCornerRadius: CGFloat = 8
        static let generalBorderWidth: CGFloat = 0.5
        static let generalIconCornerRadius: CGFloat = 4
        static let fallbackFaviconSize = CGSize(width: 36, height: 36)

        static func leadingInset(traitCollection: UITraitCollection,
                                 interfaceIdiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> CGFloat {
            guard interfaceIdiom != .phone else { return standardInset }

            // Handles multitasking on iPad
            return traitCollection.horizontalSizeClass == .regular ? iPadInset : standardInset
        }

        static func topSiteLeadingInset(traitCollection: UITraitCollection) -> CGFloat {
            guard UIDevice.current.userInterfaceIdiom != .phone else { return 0 }

            // Handles multitasking on iPad
            return traitCollection.horizontalSizeClass == .regular ? iPadTopSiteInset : 0
        }
    }

    // MARK: - Properties

    // Privacy of home page is controlled through notifications since tab manager selected tab
    // isn't always the proper privacy mode that should be reflected on the home page
    var isPrivate: Bool {
        didSet {
            childViewModels.forEach {
                $0.updatePrivacyConcernedSection(isPrivate: isPrivate)
            }
        }
    }

    let nimbus: FxNimbus
    let profile: Profile
    var isZeroSearch: Bool {
        didSet {
            topSiteViewModel.isZeroSearch = isZeroSearch
            // Ecosia: Remove `jumpBackIn` section reference
            // jumpBackInViewModel.isZeroSearch = isZeroSearch
            // Ecosia: Ecosia: Remove `recentlySaved` reference
            // recentlySavedViewModel.isZeroSearch = isZeroSearch
            // Ecosia: Remove History Highlights and Pocket
            // pocketViewModel.isZeroSearch = isZeroSearch
        }
    }

    var theme: Theme {
        didSet {
            childViewModels.forEach { $0.setTheme(theme: theme) }
        }
    }

    /// Record view appeared is sent multiple times, this avoids recording telemetry multiple times for one appearance
    var viewAppeared = false

    var shownSections = [HomepageSectionType]()
    weak var delegate: HomepageViewModelDelegate?
    private var wallpaperManager: WallpaperManager
    private var logger: Logger

    // Child View models
    private var childViewModels: [HomepageViewModelProtocol]
    var headerViewModel: HomeLogoHeaderViewModel
    // Ecosia: Remove message Card  from HomePage
    // var messageCardViewModel: HomepageMessageCardViewModel
    var topSiteViewModel: TopSitesViewModel
    // Ecosia: Remove `recentlySaved` reference
    // var recentlySavedViewModel: RecentlySavedViewModel
    // Ecosia: Remove `jumpBackIn` section reference
    // var jumpBackInViewModel: JumpBackInViewModel
    /* Ecosia: Remove History Highlights and Pocket
    var historyHighlightsViewModel: HistoryHighlightsViewModel
    var pocketViewModel: PocketViewModel
     */
    var customizeButtonViewModel: CustomizeHomepageSectionViewModel

    var shouldDisplayHomeTabBanner: Bool {
        false
        // Ecosia: Remove message Card  from HomePage
        // return messageCardViewModel.shouldDisplayMessageCard
    }
    
    // MARK: - Initializers
    init(profile: Profile,
         isPrivate: Bool,
         tabManager: TabManager,
         nimbus: FxNimbus = FxNimbus.shared,
         isZeroSearch: Bool = false,
         theme: Theme,
         wallpaperManager: WallpaperManager = WallpaperManager(),
         logger: Logger = DefaultLogger.shared) {
        self.profile = profile
        self.isZeroSearch = isZeroSearch
        self.theme = theme
        self.logger = logger

        self.headerViewModel = HomeLogoHeaderViewModel(profile: profile, theme: theme)
        /* Ecosia: Remove message Card  from HomePage
        let messageCardAdaptor = MessageCardDataAdaptorImplementation()
        self.messageCardViewModel = HomepageMessageCardViewModel(dataAdaptor: messageCardAdaptor, theme: theme)
        messageCardAdaptor.delegate = messageCardViewModel
         */
        self.topSiteViewModel = TopSitesViewModel(profile: profile,
                                                  theme: theme,
                                                  wallpaperManager: wallpaperManager)
        self.wallpaperManager = wallpaperManager

        let jumpBackInAdaptor = JumpBackInDataAdaptorImplementation(profile: profile,
                                                                    tabManager: tabManager)
        /* Ecosia: Remove `jumpBackIn` section reference
        self.jumpBackInViewModel = JumpBackInViewModel(
            profile: profile,
            isPrivate: isPrivate,
            theme: theme,
            tabManager: tabManager,
            adaptor: jumpBackInAdaptor,
            wallpaperManager: wallpaperManager)
         */
        /* Ecosia: Remove `recentlySaved` reference
        self.recentlySavedViewModel = RecentlySavedViewModel(profile: profile,
                                                             theme: theme,
                                                             wallpaperManager: wallpaperManager)
         */
        let deletionUtility = HistoryDeletionUtility(with: profile)
        let historyDataAdaptor = HistoryHighlightsDataAdaptorImplementation(
            profile: profile,
            tabManager: tabManager,
            deletionUtility: deletionUtility)
        /* Ecosia: Remove History Highlights and Pocket
        self.historyHighlightsViewModel = HistoryHighlightsViewModel(
            with: profile,
            isPrivate: isPrivate,
            theme: theme,
            historyHighlightsDataAdaptor: historyDataAdaptor,
            wallpaperManager: wallpaperManager)

        let pocketDataAdaptor = PocketDataAdaptorImplementation(pocketAPI: PocketProvider(prefs: profile.prefs))
        self.pocketViewModel = PocketViewModel(pocketDataAdaptor: pocketDataAdaptor,
                                               theme: theme,
                                               prefs: profile.prefs,
                                               wallpaperManager: wallpaperManager)
        pocketDataAdaptor.delegate = pocketViewModel
         */
        self.customizeButtonViewModel = CustomizeHomepageSectionViewModel(theme: theme)
        self.childViewModels = [headerViewModel,
                                // Ecosia: Remove message Card  from HomePage
                                // messageCardViewModel,
                                topSiteViewModel,
                                // Ecosia: Remove `jumpBackIn` section reference
                                // jumpBackInViewModel,
                                // Ecosia: Remove `recentlySaved` reference
                                // recentlySavedViewModel,
                                /* Ecosia: Remove History Highlights and Pocket
                                historyHighlightsViewModel,
                                pocketViewModel,
                                 */
                                customizeButtonViewModel]
        self.isPrivate = isPrivate

        self.nimbus = nimbus
        topSiteViewModel.delegate = self
        // Ecosia: Remove History Highlights and Pocket
        // historyHighlightsViewModel.delegate = self
        // Ecosia: Remove `recentlySaved` reference
        // recentlySavedViewModel.delegate = self
        // Ecosia: Remove History Highlights and Pocket
        // pocketViewModel.delegate = self
        // Ecosia: Remove `jumpBackIn` section reference
        // jumpBackInViewModel.delegate = self
        // Ecosia: Remove message Card  from HomePage
        // messageCardViewModel.delegate = self

        /* Ecosia: Remove `jumpBackIn` section reference
        Task {
            await jumpBackInAdaptor.setDelegate(delegate: jumpBackInViewModel)
        }
         */
        updateEnabledSections()
    }

    // MARK: - Interfaces

    func recordViewAppeared() {
        guard !viewAppeared else { return }

        viewAppeared = true
        nimbus.features.homescreenFeature.recordExposure()
        TelemetryWrapper.recordEvent(category: .action,
                                     method: .view,
                                     object: .firefoxHomepage,
                                     value: .fxHomepageOrigin,
                                     extras: TelemetryWrapper.getOriginExtras(isZeroSearch: isZeroSearch))

        // Firefox home page tracking i.e. being shown from awesomebar vs bottom right hamburger menu
        let trackingValue: TelemetryWrapper.EventValue = isZeroSearch
        ? .openHomeFromAwesomebar : .openHomeFromPhotonMenuButton
        TelemetryWrapper.recordEvent(category: .action,
                                     method: .open,
                                     object: .firefoxHomepage,
                                     value: trackingValue,
                                     extras: nil)
        childViewModels.forEach { $0.screenWasShown() }
    }

    func recordViewDisappeared() {
        viewAppeared = false
    }

    // MARK: - Manage sections

    func updateEnabledSections() {
        shownSections.removeAll()

        childViewModels.forEach {
            if $0.shouldShow { shownSections.append($0.sectionType) }
        }
        logger.log("Homepage amount of sections shown \(shownSections.count)",
                   level: .debug,
                   category: .homepage)
    }

    func refreshData(for traitCollection: UITraitCollection, size: CGSize) {
        updateEnabledSections()
        childViewModels.forEach {
            $0.refreshData(for: traitCollection,
                           size: size,
                           isPortrait: UIWindow.isPortrait,
                           device: UIDevice.current.userInterfaceIdiom)
        }
    }

    // MARK: - Section ViewModel helper

    func getSectionViewModel(shownSection: Int) -> HomepageViewModelProtocol? {
        guard let actualSectionNumber = shownSections[safe: shownSection]?.rawValue else { return nil }
        return childViewModels[safe: actualSectionNumber]
    }
}

// MARK: - HomepageDataModelDelegate
extension HomepageViewModel: HomepageDataModelDelegate {
    func reloadView() {
        delegate?.reloadView()
    }
}
