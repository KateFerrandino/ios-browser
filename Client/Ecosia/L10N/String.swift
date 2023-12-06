/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Core

extension String {
    static func localized(_ key: Key) -> String {
        localized(key.rawValue)
    }
    
    static func localized(_ string: String) -> String {
        NSLocalizedString(string, tableName: "Ecosia", comment: "")
    }
    
    static func localized(_ key: Key, incentiveRestrictedSearchAlternativeKey: Key) -> String {
        localized(Unleash.isEnabled(.incentiveRestrictedSearch) ? incentiveRestrictedSearchAlternativeKey : key)
    }

    static func localizedPlural(_ key: Key, num: Int) -> String {
        String(format: NSLocalizedString(key.rawValue, tableName: "Plurals", comment: ""), num)
    }
    
    enum Key: String {
        case allRegions = "All regions"
        case autocomplete = "Autocomplete"
        case climateImpact = "Climate Impact"
        case closeAll = "Close all"
        case customizeHomepage = "Customize homepage"
        case daysAgo = "%@ days ago"
        case ecosiaNews = "Ecosia news"
        case ecosiaRecommends = "Ecosia recommends"
        case estimatedImpact = "Estimated impact"
        case estimatedTrees = "Estimated trees"
        case exploreEcosia = "Explore Ecosia"
        case financialReports = "Financial reports"
        case forceDarkMode = "Force Dark Mode"
        case turnOffDarkMode = "Turn off Dark Mode"
        case getStarted = "Get started"
        case home = "Home"
        case homepage = "Homepage"
        case invalidReferralLink = "Invalid referral link!"
        case invalidReferralLinkMessage = "Your referral link is wrong or not valid for you. Please check it and try again."
        case invertColors = "Invert website colors"
        case inviteFriends = "Invite friends"
        case inviteFriendsSpotlight = "Help plant trees by inviting friends"
        case keepUpToDate = "Keep up to date with the latest news from our projects and more"
        case youveContributed = "You’ve contributed to plant a tree with your friend!"
        case learnMore = "Learn more"
        case linkAlreadyUsedTitle = "Link already used"
        case linkAlreadyUsedMessage = "You can only use an invitation link once."
        case makeEcosiaYourDefaultBrowser = "Make Ecosia your default browser"
        case moderate = "Moderate"
        case seeAll = "See all"
        case multiplyImpact = "Multiply impact"
        case yourImpact = "Your impact"
        case yourInvites = "Your invites"
        case growingTogether = "Growing together"
        case myImpactDescription = "This is the estimated number of trees you have contributed to planting by using Ecosia."
        case mySearches = "My searches"
        case myTrees = "My trees"
        case networkError = "Network error!"
        case new = "New"
        case noConnectionMessage = "We couldn't verify your link. Please check your internet connection and try again."
        case noConnectionNSURLErrorTitle = "No connection"
        case noConnectionNSURLErrorMessage = "Please check your internet connection and try again"
        case noConnectionNSURLErrorRefresh = "Refresh"
        case off = "Off"
        case onAverageItTakes = "On average it takes around 45 searches to plant a tree"
        case openInSafari = "Open In Safari"
        case personalizedResults = "Personalized results"
        case plantTreesWhile = "Plant trees while you browse the web"
        case privacy = "Privacy"
        case privateTab = "Private"
        case privateEmpty = "Ecosia won’t remember the pages you visited, your search history or your autofill information once you close a tab. Your searches still contribute to trees."
        case relevantResults = "Relevant results based on past searches"
        case referrals = "%d referral(s)"
        case referralAccepted = "A friend accepted your invitation and each of you will help plant 1 tree!"
        case referralsAccepted = "%@ friends accepted your invitation and each of you will help plant %@ trees!"
        case safeSearch = "Safe search"
        case search = "Search"
        case searches = "%d search(es)"
        case searchAndPlant = "Search the web to plant trees..."
        case searchRegion = "Search region"
        case sendFeedback = "Send feedback"
        case shownUnderSearchField = "Shown under the search field"
        case showOnHomepage = "Show on homepage"
        case startPlanting = "Plant your first tree"
        case strict = "Strict"
        case tapCounter = "Tap your tree counter to share Ecosia with friends and plant more trees"
        case terms = "Terms and conditions"
        case today = "Today"
        case togetherWeCan = "Together, we can reforest our planet. Tap your counter to spread the word!"
        case topSites = "Top Sites"
        case totalEcosiaTrees = "Total Ecosia trees"
        case treesPlural = "%d tree(s)"
        case trees = "TREES"
        case treesUpdate = "Trees update"
        case treesPlantedWithEcosia = "TREES PLANTED WITH ECOSIA"
        case useTheseCompanies = "Start using these green companies to plant more trees and become more sustainable"
        case version = "Version %@"
        case viewMyImpact = "View my impact"
        case weUseTheProfit = "We use the profit from your searches to plant trees where they are needed most"
        case helpUsImprove = "Help us improve our new app"
        case letUsKnowWhat = "Let us know what you like, dislike, and want to see in the future."
        case shareYourFeedback = "Share your feedback"
        case sitTightWeAre = "Sit tight, we are getting ready for you…"
        case weHitAGlitch = "We hit a glitch"
        case weAreMomentarilyUnable = "We are momentarily unable to load all of your settings."
        case continueMessage = "Continue"
        case retryMessage = "Retry"
        case setAsDefaultBrowser = "Set Ecosia as default browser"
        case linksFromWebsites = "Links from websites, emails or messages will automatically open in Ecosia."
        case showTopSites = "Show Top Sites"
        case helpYourFriendsBecome = "Help your friends become climate active and plant trees together"
        case friendsJoined = "%d friend(s) joined"
        case acceptedInvites = "%d accepted invite(s)"
        case invitingAFriend = "Inviting a friend"
        case inviteYourFriends = "Invite your friends"
        case sendAnInvite = "Send an invite with your unique invitation link"
        case theyDownloadTheApp = "They download the Ecosia app"
        case viaTheAppStore = "Via the AppStore (invites for Android are coming soon)"
        case theyOpenYourInviteLink = "They open your invite link"
        case yourFriendClicks = "Your friend clicks on your unique link from the invite message"
        case eachOfYouHelpsPlant = "Each of you helps plant a tree"
        case whenAFriendUses = "When a friend uses your invite link, you both plant an extra tree"
        case noBookmarksYet = "No bookmarks yet"
        case AddYourFavoritePages = "Add your favorite pages to your bookmarks and they will appear here"
        case noArticles = "No articles on your reading list"
        case openArticlesInReader = "Open articles in Reader View by tapping the page icon in the address bar"
        case saveArticlesToReader = "Save articles to your Reading list by tapping on ‘Add to Reading List’ in the options while in Reader View"
        case noHistory = "No history"
        case websitesYouHave = "Websites you’ve recently visited will show up here"
        case noDownloadsYet = "No downloads yet"
        case whenYouDownloadFiles = "When you download files they will show up here"
        case iThinkYouWillLikeThis = "Hey, I think you’ll like this!\nDid you know that Ecosia is the only search engine that uses 100%% of their profits for climate action? 🌍\nJoin me and %@M+ others planting the right trees in the right places."
        case downloadTheApp = "1. Download the app:"
        case useMyInviteLink = "2. Use my ✨ invite link ✨ and we will both plant an extra tree 🌳\n(Android coming soon):"
        case seeTheCollectiveImpact  = "See the collective impact you are having with the Ecosia community"
        case theSimplestWay = "The simplest way to be \n climate-active every day while \n browsing the web"
        case skipWelcomeTour = "Skip welcome tour"
        case aBetterPlanet = "A better planet with every search"
        case searchTheWeb = "Search the web and plant trees with the fast, free, and full-featured Ecosia browser"
        case grennestWayToSearch = "The greenest way to search"
        case planetFriendlySearch = "Ecosia is the world's most planet-friendly way to search - and it's free."
        case hundredPercentOfProfits = "100% of profits for the planet"
        case weUseAllOurProfits = "We use all our profits for climate action, such as planting trees and generating solar energy."
        case collectiveAction = "Collective action starts here"
        case join15Million = "Join 15 million people growing the right trees in the right places."
        case weWantTrees = "We want your trees, not your data"
        case weDontCreateAProfile = "We don’t create a profile of you and will never sell your details to advertisers."
        case realResults = "Real results, transparent finances"
        case shownExactlyHowMuch = "You're shown exactly how much we earn and invest in trees and climate action."
        case totalIncome = "Total income"
        case treesFinanced = "Trees financed"
        case skip = "Skip"
        case treesPlanted = "Trees planted"
        case sustainableShoes = "sustainable shoes"
        case before = "Before ..."
        case after = "After"
        case treesPlantedByTheCommunity = "trees planted by the Ecosia community"
        case treesPlantedByTheCommunityCapitalized = "Trees planted by the Ecosia community"
        case investedIntoClimateAction = "invested into climate action"
        case activeProjects = "Active projects"
        case countries = "Countries"
        case finishTour = "Start Planting"
        case treesPlantedPlural = "Tree(s) planted"
        case howItWorks = "How it works"
        case friendInvitesPlural = "%d friend invite(s)"
        case openSettings = "Open settings"
        case maybeLater = "Maybe later"
        case openAllLinksToPlantTrees = "Open all links with Ecosia to plant more trees"
        case openAllLinksAutomatically = "Open all links automatically with Ecosia"
        case growYourImpact = "Grow your impact with your web searches"
        case beClimateActive = "Be climate active every day while browsing"
        case groupYourImpact = "Group your impact"
        case getATreeWithEveryFriend = "Get a tree with every friend who joins. They get one too!"
        case aboutEcosia = "About Ecosia"
        case seeHowMuchMoney = "See exactly how much money we made, how we spent it, and how many trees we planted."
        case discoverWhereWe = "Discover where we plant trees, and find out how our tree planting projects across the globe are doing."
        case learnHowWe = "Learn how we protect your privacy by encrypting your searches, never selling your data to advertisers without your permission and more."
        case findAnswersTo = "Find answers to popular questions like how Ecosia neutralizes CO2 emissions and what it means to be a social business."
        case aboutEcosiaCollapseAccessibility = "Interact to collapse content"
        case aboutEcosiaExpandAccessibility = "Interact to expand content"
        case customization = "Customization"
        case clearAll = "Clear all"
        case searchBarHint = "To make entering info easier, the toolbar can be set to the bottom of the screen"
        case buyTrees = "Buy trees in the Ecosia tree store to delight a friend - or treat yourself"
        case plantTreesAndEarn = "Plant trees and earn eco-friendly rewards with Treecard"
        case sponsored = "Sponsored"
        case inviteYourFriendsToCheck = "Invite your friends to check out Ecosia. When they join, you both plant an extra tree."
        case sharingYourLink = "Sharing your link"
        case copy = "Copy"
        case moreSharingMethods = "More sharing methods"
        case copied = "Copied!"
        case plantTreesWithMe = "Plant trees with me on Ecosia"
        case ecosiaLogoAccessibilityLabel = "Ecosia logo"
        case done = "Done"
        case findInPage = "Find in page"
        case exportBookmarks = "Export bookmarks"
        case importBookmarks = "Import bookmarks"
        case exportingBookmarks = "Exporting Bookmarks…"
        case importingBookmarks = "Importing Bookmarks…"
        case importedBookmarkFolderName = "Imported Bookmarks (%@)"
        case bookmarksImportFailedTitle = "Importing failed"
        case bookmarksExportFailedTitle = "Exporting failed"
        case bookmarksImportExportFailedMessage = "Something went wrong, please try again."
        case bookmarksPanelMore = "More"
        case bookmarksImported = "Bookmarks imported"
        case bookmarksExported = "Bookmarks exported"
        case bookmarksEmptyViewItem0 = "Tap the bookmark icon when you find a page you want to save."
        case bookmarksEmptyViewItem1 = "You can also import bookmarks:"
        case bookmarksEmptyViewItem1NumberedItem0 = "Export your bookmarks from another browser."
        case bookmarksEmptyViewItem1NumberedItem1 = "Tap on the link below to import the file of your bookmarks"
        case bookmarksNtpNudgeCardDescription = "You can now import bookmarks from other browsers to Ecosia."
        case bookmarksNtpNudgeCardButtonTitle = "Open bookmarks"
        case bookmarksToolTipText = "Tap here to import bookmarks from other browsers."
        case cancel = "Cancel"
        case open = "Open"
        case openExternalLinkTitle = "Open link in external app?"
        case openExternalLinkDescription = "%@ wants to open this application."
        case sendUsageDataSettingsTitle = "Send usage data"
        case sendUsageDataSettingsDescription = "To improve our browser apps, we collect usage statistics from your device. These are anonymous and protect your privacy."
        case impactSectionAccessibilityHint = "Open the Your Impact section"
        case impactSectionAccessibilityLabel = "Your Impact section, highlithing the trees planted by yourself and the Ecosia community overall. You have contributed to plant %@ trees. The total number of trees planted by the Ecosia community has reached %@"
        case onboardingPageControlDotsAccessibility = "Page control dots"
        case onboardingBackButtonAccessibility = "Back"
        case onboardingSkipTourButtonAccessibility = "Skip the onboarding"
        case onboardingContinueCTAButtonAccessibility = "Continue to the next onboarding page"
        case onboardingFinishCTAButtonAccessibility = "Finish onboarding and start contributing to Ecosia"
        case onboardingIllustrationTour1 = "This onboarding illustration shows how by performing searches via the Ecosia app, you are leveling up your tree planting impact score. A small search screenshot and a tree counter example is shown. A forest can be seen on the background."
        case onboardingIllustrationTour1Alternative = "This onboarding illustration shows how by performing searches via the Ecosia app, you are leveling up your planed-friendly lifestyle. A small search input field screenshot and result example containing the green icon is shown. A forest can be seen on the background."
        case onboardingIllustrationTour2 = "This onboarding illustration shows briefly an example of a before and after comparision of trees planted in a land. The image is a screenshot from the satellite view."
        case onboardingIllustrationTour3 = "This onboarding illustration shows a few numbers like the projects Ecosia is involved in, the total number of trees planted by the Ecosia community, alongisde the number of countries Ecosia is active. A small map of the planisphere with trees pins in few geographic location, background."
        case onboardingIllustrationTour4 = "This onboarding illustration is a photo of a monkey climbing a tree. It function mainly as general decoration image."
        case onboardingIllustrationTour4Alternative = "This onboarding illustration shows the latest financial reports of Ecosia. On the background there is an image of a person caring for tree seedlings"
        case whatsNewViewTitle = "What's new"
        case whatsNewFirstItemTitle = "Collective action"
        case whatsNewFirstItemDescription = "See the climate impact you are having together with the rest of the Ecosia community."
        case whatsNewSecondItemTitle = "Customizable home page"
        case whatsNewSecondItemDescription = "Tailor your home page to show the information that’s most relevant to you."
        case whatsNewFooterButtonTitle = "Discover"
        case quickSearch = "Quick Search"
        case apnConsentVariantNameControlHeaderTitle = "Keep up with Ecosia"
        case apnConsentVariantNameTest1HeaderTitle = "Turn on push notifications"
        case apnConsentVariantNameControlFirstItemTitle = "Discover the trees we plant and the impact they’re having"
        case apnConsentVariantNameControlSecondItemTitle = "Get tips on how to help build a greener future"
        case apnConsentVariantNameTest1FirstItemTitle = "Receive updates on our tree-planting projects around the world"
        case apnConsentVariantNameTest1SecondItemTitle = "Get tips on how to be climate active every day"
        case apnConsentCTAAllowButtonTitle = "Allow push notifications"
        case apnConsentCTADenyButtonTitle = "Not now"
    }
}
