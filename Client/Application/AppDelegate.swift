// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Shared
import Storage
import CoreSpotlight
import SDWebImage
import Core

let LatestAppVersionProfileKey = "latestAppVersion"

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var browserViewController: BrowserViewController!
    var rootViewController: UINavigationController!
    var tabManager: TabManager!
    var receivedURLs = [URL]()
    var orientationLock = UIInterfaceOrientationMask.all
    lazy var profile: Profile = BrowserProfile(localName: "profile")
    private let log = Logger.browserLogger
    private var shutdownWebServer: DispatchSourceTimer?
    private var webServerUtil: WebServerUtil?
    private var appLaunchUtil: AppLaunchUtil?
    // Ecosia: Disable BG sync // private var backgroundSyncUtil: BackgroundSyncUtil?

    func application(_ application: UIApplication,
                     willFinishLaunchingWithOptions
                     launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        log.info("startApplication begin")

        self.window = UIWindow(frame: UIScreen.main.bounds)
        window?.tintColor = .theme.ecosia.primaryBrand
        
        appLaunchUtil = AppLaunchUtil(profile: profile)
        appLaunchUtil?.setUpPreLaunchDependencies()
        
        // Set up a web server that serves us static content. Do this early so that it is ready when the UI is presented.
        webServerUtil = WebServerUtil(profile: profile)
        webServerUtil?.setUpWebServer()

        let imageStore = DiskImageStore(files: profile.files, namespace: "TabManagerScreenshots", quality: UIConstants.ScreenshotQuality)
        self.tabManager = TabManager(profile: profile, imageStore: imageStore)

        setupRootViewController()
        startListeningForThemeUpdates()

        log.info("startApplication end")

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // We have only five seconds here, so let's hope this doesn't take too long.
        profile._shutdown(force: true)

        // Allow deinitializers to close our database connections.
        tabManager = nil
        browserViewController = nil
        rootViewController = nil
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions
                     launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window!.makeKeyAndVisible()
        // Ecosia: pushNotificationSetup()
        appLaunchUtil?.setUpPostLaunchDependencies()
        // Ecosia: Update EcosiaInstallType if needed
        EcosiaInstallType.evaluateCurrentEcosiaInstallType()
        // Ecosia: Disable BG sync //backgroundSyncUtil = BackgroundSyncUtil(profile: profile, application: application)
        // Ecosia: lifecycle tracking
        Analytics.shared.activity(.launch)
        
        /* 
         Ecosia: Feature Management fetch
         We perform the same configuration retrieval in
         `applicationDidBecomeActive(:)` and sounds redundant;
         However we need it here to make sure we retrieve the latest
         flag state of the EngagementService.
         Decouple the "loading" only from the filesystem of any
         previously saved Model from the `Unleash.start(:)` will not
         make any tangible difference in the process as we check if
         any cached version of the Model is in place.
         */
        Task {
            await FeatureManagement.fetchConfiguration()
            // Ecosia: Engagement Service Initialization helper
            ClientEngagementService.shared.initializeAndUpdateNotificationRegistrationIfNeeded(notificationCenterDelegate: self)
        }
        
        // Ecosia: fetching statistics before they are used
        Task.detached {
            try? await Statistics.shared.fetchAndUpdate()
        }

        return true
    }

    // We sync in the foreground only, to avoid the possibility of runaway resource usage.
    // Eventually we'll sync in response to notifications.
    func applicationDidBecomeActive(_ application: UIApplication) {
        shutdownWebServer?.cancel()
        shutdownWebServer = nil

        profile._reopen()

        /*
        if profile.prefs.boolForKey(PendingAccountDisconnectedKey) ?? false {
            profile.removeAccount()
        }

        profile.syncManager.applicationDidBecomeActive()
         */
        webServerUtil?.setUpWebServer()

        /// When transitioning to scenes, each scene's BVC needs to resume its file download queue.
        browserViewController.downloadQueue.resumeAll()

        TelemetryWrapper.recordEvent(category: .action, method: .foreground, object: .app)

        // Delay these operations until after UIKit/UIApp init is complete
        // - loadQueuedTabs accesses the DB and shows up as a hot path in profiling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // We could load these here, but then we have to futz with the tab counter
            // and making NSURLRequests.
            self.browserViewController.loadQueuedTabs(receivedURLs: self.receivedURLs)
            self.receivedURLs.removeAll()
            application.applicationIconBadgeNumber = 0
        }
        // Create fx favicon cache directory
        FaviconFetcher.createWebImageCacheDirectory()
        // update top sites widget
        updateTopSitesWidget()

        // Cleanup can be a heavy operation, take it out of the startup path. Instead check after a few seconds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.profile.cleanupHistoryIfNeeded()
            self.browserViewController.ratingPromptManager.updateData()
        }

        // Ecosia
        Task {
            await FeatureManagement.fetchConfiguration()
        }
        MMP.sendSession()
    }

    func applicationWillResignActive(_ application: UIApplication) {
        updateTopSitesWidget()
        UserDefaults.standard.setValue(Date(), forKey: "LastActiveTimestamp")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Pause file downloads.
        // TODO: iOS 13 needs to iterate all the BVCs.
        browserViewController.downloadQueue.pauseAll()

        TelemetryWrapper.recordEvent(category: .action, method: .background, object: .app)
        TabsQuantityTelemetry.trackTabsQuantity(tabManager: tabManager)

        let singleShotTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        // 2 seconds is ample for a localhost request to be completed by GCDWebServer. <500ms is expected on newer devices.
        singleShotTimer.schedule(deadline: .now() + 2.0, repeating: .never)
        singleShotTimer.setEventHandler {
            WebServer.sharedInstance.server.stop()
            self.shutdownWebServer = nil
        }
        singleShotTimer.resume()
        shutdownWebServer = singleShotTimer
        /* Ecosia: deactivate MZ background sync
        backgroundSyncUtil?.scheduleSyncOnAppBackground()
        */
        tabManager.preserveTabs()

        // send glean telemetry and clear cache
        // we do this to remove any disk cache
        // that the app might have built over the
        // time which is taking up un-necessary space
        SDImageCache.shared.clearDiskCache { _ in }
    }

    private func updateTopSitesWidget() {
        // Since we only need the topSites data in the archiver, let's write it
        // only if iOS 14 is available.
        if #available(iOS 14.0, *) {
            let topSitesProvider = TopSitesProviderImplementation(browserHistoryFetcher: profile.history,
                                                                  prefs: profile.prefs)

            TopSitesWidgetManager(topSitesProvider: topSitesProvider).writeWidgetKitTopSites()
        }
    }

    /// When a user presses and holds the app icon from the Home Screen, we present quick actions / shortcut items (see QuickActions).
    ///
    /// This method can handle a quick action from both app launch and when the app becomes active. However, the system calls launch methods first if the app `launches`
    /// and gives you a chance to handle the shortcut there. If it's not handled there, this method is called in the activation process with the shortcut item.
    ///
    /// Quick actions / shortcut items are handled here as long as our two launch methods return `true`. If either of them return `false`, this method
    /// won't be called to handle shortcut items.
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let handledShortCutItem = QuickActions.sharedInstance.handleShortCutItem(shortcutItem, withBrowserViewController: browserViewController)

        completionHandler(handledShortCutItem)
    }

    // Ecosia: lifecycle tracking
    func applicationWillEnterForeground(_ application: UIApplication) {
        Analytics.shared.activity(.resume)
    }
}

// This functionality will need to be moved to the SceneDelegate when the time comes
extension AppDelegate {

    func startListeningForThemeUpdates() {
        NotificationCenter.default.addObserver(forName: .DisplayThemeChanged, object: nil, queue: .main) { [weak self] (_) -> Void in
            self?.window?.tintColor = .theme.ecosia.primaryBrand
            if !LegacyThemeManager.instance.systemThemeIsOn {
                self?.window?.overrideUserInterfaceStyle = LegacyThemeManager.instance.userInterfaceStyle
            } else {
                self?.window?.overrideUserInterfaceStyle = .unspecified
            }
        }
    }

    // Orientation lock for views that use new modal presenter
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return self.orientationLock
    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == SiriShortcuts.activityType.openURL.rawValue {
            browserViewController.openBlankNewTab(focusLocationField: false)
            return true
        }

        // If the `NSUserActivity` has a `webpageURL`, it is either a deep link or an old history item
        // reached via a "Spotlight" search before we began indexing visited pages via CoreSpotlight.
        if let url = userActivity.webpageURL {
            let query = url.getQuery()

            // Check for fxa sign-in code and launch the login screen directly
            if query["signin"] != nil {
                // bvc.launchFxAFromDeeplinkURL(url) // Was using Adjust. Consider hooking up again when replacement system in-place.
                return true
            }

            // Per Adjust documentation, https://docs.adjust.com/en/universal-links/#running-campaigns-through-universal-links,
            // it is recommended that links contain the `deep_link` query parameter. This link will also
            // be url encoded.
            if let deepLink = query["deep_link"]?.removingPercentEncoding, let url = URL(string: deepLink) {
                browserViewController.switchToTabForURLOrOpen(url)
                return true
            }

            browserViewController.switchToTabForURLOrOpen(url)
            return true
        }

        // Otherwise, check if the `NSUserActivity` is a CoreSpotlight item and switch to its tab or
        // open a new one.
        if userActivity.activityType == CSSearchableItemActionType {
            if let userInfo = userActivity.userInfo,
                let urlString = userInfo[CSSearchableItemActivityIdentifier] as? String,
                let url = URL(string: urlString) {
                browserViewController.switchToTabForURLOrOpen(url)
                return true
            }
        }

        return false
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard let routerpath = NavigationPath(url: url) else { return false }

        if let _ = profile.prefs.boolForKey(PrefsKeys.AppExtensionTelemetryOpenUrl) {
            profile.prefs.removeObjectForKey(PrefsKeys.AppExtensionTelemetryOpenUrl)
            var object = TelemetryWrapper.EventObject.url
            if case .text = routerpath {
                object = .searchText
            }
            TelemetryWrapper.recordEvent(category: .appExtensionAction, method: .applicationOpenUrl, object: object)
        }

        DispatchQueue.main.async {
            NavigationPath.handle(nav: routerpath, with: self.browserViewController)
        }
        return true
    }

    private func setupRootViewController() {
        if !LegacyThemeManager.instance.systemThemeIsOn {
            window?.overrideUserInterfaceStyle = LegacyThemeManager.instance.userInterfaceStyle
        }

        browserViewController = BrowserViewController(profile: profile, tabManager: tabManager)
        browserViewController.edgesForExtendedLayout = []

        // Ecosia: custom root logic
        let rootVC: UIViewController

        if User.shared.firstTime {
            rootVC = Welcome(delegate: self)
            Analytics.shared.install()
        } else {
            rootVC = browserViewController!
        }

        let navigationController = WelcomeNavigation(rootViewController: rootVC)
        navigationController.isNavigationBarHidden = true
        navigationController.edgesForExtendedLayout = UIRectEdge(rawValue: 0)
        rootViewController = navigationController
        window!.rootViewController = rootViewController
    }
}

extension AppDelegate: WelcomeDelegate {
    func welcomeDidFinish(_ welcome: Welcome) {
        rootViewController.setViewControllers([browserViewController], animated: true)
    }
}

// Ecosia: Conformance to UNUserNotificationCenterDelegate to enable APN

extension AppDelegate: UNUserNotificationCenterDelegate {}

// Ecosia: Register the APN device token

extension AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        ClientEngagementService.shared.registerDeviceToken(deviceToken)
    }
}

