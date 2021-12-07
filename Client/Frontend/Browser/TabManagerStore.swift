/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Storage
import Shared
import XCGLogger
import Core

private let log = Logger.browserLogger
class TabManagerStore: FeatureFlagsProtocol {
    fileprivate var lockedForReading = false
    fileprivate let imageStore: DiskImageStore?
    fileprivate var fileManager = FileManager.default
    fileprivate let prefs: Prefs
    fileprivate let serialQueue = DispatchQueue(label: "tab-manager-write-queue")
    fileprivate var writeOperation = DispatchWorkItem {}

    // Init this at startup with the tabs on disk, and then on each save, update the in-memory tab state.
    fileprivate lazy var archivedStartupTabs: [SavedTab] = {
        /* Ecosia: restore from Ecosia Tabs the first time */
        if Core.User.shared.migrated != true {
            return migrateToSavedTabs(from: Core.Tabs()) ?? []
        }

        return SiteArchiver.tabsToRestore(tabsStateArchivePath: tabsStateArchivePath()).0
    }()

    init(imageStore: DiskImageStore?, _ fileManager: FileManager = FileManager.default, prefs: Prefs) {
        self.fileManager = fileManager
        self.imageStore = imageStore
        self.prefs = prefs
    }

    var isRestoringTabs: Bool {
        return lockedForReading
    }

    var shouldOpenHome: Bool {
        let isColdLaunch = NSUserDefaultsPrefs(prefix: "profile").boolForKey("isColdLaunch")
        guard let coldLaunch = isColdLaunch, featureFlags.isFeatureActiveForBuild(.startAtHome) else { return false }
        // TODO: When fixing start at home, the below code is correct, but needs to be
        // uncommented in order to get the feature working properly
//        guard let setting: StartAtHomeSetting = featureFlags.featureOption(.startAtHome) else { return false }
//
//        let lastActiveTimestamp = UserDefaults.standard.object(forKey: "LastActiveTimestamp") as? Date ?? Date()
//        let dateComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: lastActiveTimestamp, to: Date())
//
//        var timeSinceLastActivity: Int
//        var timeToOpenNewHome: Int
//        switch setting {
//        case .afterFourHours:
//            timeSinceLastActivity = dateComponents.hour ?? 0
//            timeToOpenNewHome = 4
//
//        case .always:
//            // ROUX: this needs to be MINUTES. Currently seconds for testing
//            timeSinceLastActivity = dateComponents.second ?? 0
//            timeToOpenNewHome = 5
//
//        case .never: return false // should never get here, but the switch must be exhaustive
//        }
//
//        return timeSinceLastActivity >= timeToOpenNewHome || coldLaunch

        return false
    }

    var hasTabsToRestoreAtStartup: Bool {
        return archivedStartupTabs.count > 0
    }

    fileprivate func tabsStateArchivePath() -> String? {
        let profilePath: String?
        if  AppConstants.IsRunningTest || AppConstants.IsRunningPerfTest {      profilePath = (UIApplication.shared.delegate as? TestAppDelegate)?.dirForTestProfile
        } else {
            profilePath = fileManager.containerURL( forSecurityApplicationGroupIdentifier: AppInfo.sharedContainerIdentifier)?.appendingPathComponent("profile.profile").path
        }
        guard let path = profilePath else { return nil }
        return URL(fileURLWithPath: path).appendingPathComponent("tabsState.archive").path
    }

    fileprivate func prepareSavedTabs(fromTabs tabs: [Tab], selectedTab: Tab?) -> [SavedTab]? {
        var savedTabs = [SavedTab]()
        var savedUUIDs = Set<String>()
        for tab in tabs {
            tab.tabUUID = tab.tabUUID.isEmpty ? UUID().uuidString : tab.tabUUID
            tab.screenshotUUID = tab.screenshotUUID ?? UUID()
            tab.firstCreatedTime = tab.firstCreatedTime ?? tab.sessionData?.lastUsedTime ?? Date.now()
            if let savedTab = SavedTab(tab: tab, isSelected: tab == selectedTab) {
                savedTabs.append(savedTab)
                if let uuidString = tab.screenshotUUID?.uuidString {
                    savedUUIDs.insert(uuidString)
                }
            }
        }

        // Clean up any screenshots that are no longer associated with a tab.
        _ = imageStore?.clearExcluding(savedUUIDs)
        return savedTabs.isEmpty ? nil : savedTabs
    }

    func preserveScreenshot(forTab tab: Tab?) {
        if let tab = tab, let screenshot = tab.screenshot, let uuidString = tab.screenshotUUID?.uuidString {
            imageStore?.put(uuidString, image: screenshot)
        }
    }

    // Async write of the tab state. In most cases, code doesn't care about performing an operation
    // after this completes. Deferred completion is called always, regardless of Data.write return value.
    // Write failures (i.e. due to read locks) are considered inconsequential, as preserveTabs will be called frequently.
    @discardableResult func preserveTabs(_ tabs: [Tab], selectedTab: Tab?) -> Success {
        assert(Thread.isMainThread)
        print("preserve tabs!, existing tabs: \(tabs.count)")
        guard let savedTabs = prepareSavedTabs(fromTabs: tabs, selectedTab: selectedTab),
            let path = tabsStateArchivePath() else {
                clearArchive()
                return succeed()
        }

        writeOperation.cancel()

        let tabStateData = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: tabStateData)

        archiver.encode(savedTabs, forKey: "tabs")
        archiver.finishEncoding()

        let simpleTabs = SimpleTab.convertToSimpleTabs(savedTabs)


        let result = Success()
        writeOperation = DispatchWorkItem {
            let written = tabStateData.write(toFile: path, atomically: true)

            SimpleTab.saveSimpleTab(tabs: simpleTabs)
            // Ignore write failure (could be restoring).
            log.debug("PreserveTabs write ok: \(written), bytes: \(tabStateData.length)")
            result.fill(Maybe(success: ()))
        }

        // Delay by 100ms to debounce repeated calls to preserveTabs in quick succession.
        // Notice above that a repeated 'preserveTabs' call will 'cancel()' a pending write operation.
        serialQueue.asyncAfter(deadline: .now() + 0.100, execute: writeOperation)

        return result
    }

    func restoreStartupTabs(clearPrivateTabs: Bool, tabManager: TabManager) -> Tab? {
        let selectedTab = restoreTabs(savedTabs: archivedStartupTabs, clearPrivateTabs: clearPrivateTabs, tabManager: tabManager)
        return selectedTab
    }

    func restoreTabs(savedTabs: [SavedTab], clearPrivateTabs: Bool, tabManager: TabManager) -> Tab? {
        assertIsMainThread("Restoration is a main-only operation")
        guard !lockedForReading, savedTabs.count > 0 else { return nil }
        lockedForReading = true
        defer {
            lockedForReading = false
        }
        var savedTabs = savedTabs
        // Make sure to wipe the private tabs if the user has the pref turned on
        if clearPrivateTabs {
            savedTabs = savedTabs.filter { !$0.isPrivate }
        }

        var tabToSelect: Tab?

        var fxHomeTab: Tab?
        var customHomeTab: Tab?
        let wasLastSessionPrivate = UserDefaults.standard.bool(forKey: "wasLastSessionPrivate")

        for savedTab in savedTabs {
            // Provide an empty request to prevent a new tab from loading the home screen
            var tab = tabManager.addTab(flushToDisk: false, zombie: true, isPrivate: savedTab.isPrivate)
            tab = savedTab.configureSavedTabUsing(tab, imageStore: imageStore)
            if savedTab.isSelected {
                tabToSelect = tab
            }

            // select Home Tab for correct previous private / regular session
            if tab.isPrivate == wasLastSessionPrivate {
                fxHomeTab = tab.isFxHomeTab ? tab : nil
            }

            customHomeTab = tab.isCustomHomeTab ? tab : nil
        }

        if tabToSelect == nil {
            tabToSelect = tabManager.tabs.first(where: { $0.isPrivate == false })
        }

        return tabToSelect
    }

    func shouldOpenHomeWith(tabManager: TabManager) -> Tab? {
        var fxHomeTab: Tab?
        var customHomeTab: Tab?

        if shouldOpenHome {
            let page = NewTabAccessors.getHomePage(prefs)
            let customUrl = HomeButtonHomePageAccessors.getHomePage(prefs)
            let homeUrl = URL(string: "internal://local/about/home")

            if page == .homePage, let customUrl = customUrl {
                return customHomeTab ?? tabManager.addTab(URLRequest(url: customUrl))
            } else if page == .topSites, let homeUrl = homeUrl {
                let home = fxHomeTab ?? tabManager.addTab()
                home.loadRequest(PrivilegedRequest(url: homeUrl) as URLRequest)
                home.url = homeUrl
                return home
            }
        }

        return tabManager.selectedTab
    }

    func clearArchive() {
        if let path = tabsStateArchivePath() {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}

// Functions for testing
extension TabManagerStore {
    func testTabCountOnDisk() -> Int {
        assert(AppConstants.IsRunningTest)
        return SiteArchiver.tabsToRestore(tabsStateArchivePath: tabsStateArchivePath()).0.count
    }
}

// Ecosia: import tabs
extension TabManagerStore {

    fileprivate func migrateToSavedTabs(from tabs: Core.Tabs) -> [SavedTab]? {
        var savedTabs = [SavedTab]()
        var savedUUIDs = Set<String>()

        var currentTabID: UUID?
        if let pos = tabs.current, pos < tabs.items.count {
            currentTabID = tabs.items[pos].id
        }

        for tab in tabs.items {
            guard let page = tab.page else { continue }
            let sessionData = SessionData(currentPage: 0, urls: [page.url], lastUsedTime: Date.now())
            guard let savedTab = SavedTab(screenshotUUID: tab.id,
                                          isSelected: currentTabID == tab.id,
                                          title: page.title,
                                          isPrivate: false,
                                          faviconURL: nil,
                                          url: page.url,
                                          sessionData: sessionData,
                                          uuid: tab.id.uuidString,
                                          tabGroupData: nil,
                                          createdAt: sessionData.lastUsedTime) else  { continue }

            savedTabs.append(savedTab)

            if let data = tab.snapshot, let image = UIImage(data: data) {
                savedUUIDs.insert(tab.id.uuidString)
                imageStore?.put(tab.id.uuidString, image: image)
            }
        }
        // Clean up any screenshots that are no longer associated with a tab.
        _ = imageStore?.clearExcluding(savedUUIDs)
        return savedTabs.isEmpty ? nil : savedTabs
    }
}

