// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit
import Shared
import Storage
import XCGLogger
import WebKit
import os.log

private class FetchInProgressError: MaybeErrorType {
    internal var description: String {
        return "Fetch is already in-progress"
    }
}

@objcMembers
class HistoryPanel: UIViewController, LibraryPanel, Loggable, NotificationThemeable {

    struct UX {
        static let WelcomeScreenItemWidth = 170
        static let HeaderHeight = CGFloat(40)
        static let IconSize = 23
        static let IconBorderColor = UIColor.Photon.Grey30
        static let IconBorderWidth: CGFloat = 0.5
        static let actionIconColor = UIColor.Photon.Grey40 // Works for light and dark theme.
        static let EmptyTabContentOffset: CGFloat = -180
    }

    // MARK: - Properties
    typealias HistoryPanelSections = HistoryPanelViewModel.Sections
    typealias a11yIds = AccessibilityIdentifiers.LibraryPanels.HistoryPanel

    var libraryPanelDelegate: LibraryPanelDelegate?
    var recentlyClosedTabsDelegate: RecentlyClosedPanelDelegate?
    var state: LibraryPanelMainState

    let profile: Profile
    let viewModel: HistoryPanelViewModel
    private let clearHistoryHelper: ClearHistorySheetProvider
    var keyboardState: KeyboardState?
    private lazy var siteImageHelper = SiteImageHelper(profile: profile)
    var chevronImage = UIImage(named: ImageIdentifiers.menuChevron)

    // We'll be able to prefetch more often the higher this number is. But remember, it's expensive!
    private let historyPanelPrefetchOffset = 8
    var diffableDatasource: UITableViewDiffableDataSource<HistoryPanelSections, AnyHashable>?

    var shouldShowToolBar: Bool {
        return state == .history(state: .mainView) || state == .history(state: .search)
    }

    var shouldShowSearch: Bool {
        /* Ecosia: disable flag
        guard viewModel.featureFlags.isFeatureEnabled(.historyGroups, checking: .buildOnly) else {
            return false
        }
         */

        return state == .history(state: .mainView) || state == .history(state: .search)
    }

    var bottomToolbarItems: [UIBarButtonItem] {
        guard case .history = state else { return [UIBarButtonItem]() }

        return toolbarButtonItems
    }

    private var toolbarButtonItems: [UIBarButtonItem] {
        guard shouldShowToolBar else {
            return [UIBarButtonItem]()
        }

        guard shouldShowSearch else {
            return [bottomDeleteButton, flexibleSpace]
        }

        return [flexibleSpace, bottomSearchButton, flexibleSpace, bottomDeleteButton]
    }

    // UI
    private lazy var bottomSearchButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage.templateImageNamed(ImageIdentifiers.libraryPanelSearch),
                                     style: .plain,
                                     target: self,
                                     action: #selector(bottomSearchButtonAction))
        button.accessibilityIdentifier = AccessibilityIdentifiers.LibraryPanels.bottomSearchButton
        return button
    }()

    private lazy var bottomDeleteButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: .localized(.clearAll),
                                     style: .plain,
                                     target: self,
                                     action: #selector(bottomDeleteButtonAction))
        button.accessibilityIdentifier = AccessibilityIdentifiers.LibraryPanels.bottomDeleteButton
        return button
    }()

    var bottomStackView: BaseAlphaStackView = .build { view in
        view.isClearBackground = true
    }

    lazy var searchSeparator: UIView = .build { view in
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
    }

    var placeholder: NSAttributedString {
        return NSAttributedString(string: viewModel.searchHistoryPlaceholder, attributes: [NSAttributedString.Key.foregroundColor: UIColor.theme.ecosia.secondaryText])
    }

    lazy var searchbar: UISearchBar = .build { searchbar in
        searchbar.searchBarStyle = .prominent
        searchbar.returnKeyType = .go
        searchbar.delegate = self
        searchbar.searchTextField.layer.cornerRadius = 18
        searchbar.searchTextField.layer.masksToBounds = true
        searchbar.backgroundImage = .init()
    }

    lazy private var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self.diffableDatasource
        tableView.addGestureRecognizer(self.longPressRecognizer)
        tableView.accessibilityIdentifier = a11yIds.tableView
        tableView.prefetchDataSource = self
        tableView.delegate = self
        tableView.register(TwoLineImageOverlayCell.self, forCellReuseIdentifier: TwoLineImageOverlayCell.cellIdentifier)
        tableView.register(TwoLineImageOverlayCell.self, forCellReuseIdentifier: TwoLineImageOverlayCell.accessoryUsageReuseIdentifier)
        tableView.register(OneLineTableViewCell.self, forCellReuseIdentifier: OneLineTableViewCell.cellIdentifier)
        tableView.register(SiteTableViewHeader.self, forHeaderFooterViewReuseIdentifier: SiteTableViewHeader.cellIdentifier)

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.contentInset.top = 32
        return tableView
    }()

    lazy var longPressRecognizer: UILongPressGestureRecognizer = {
        UILongPressGestureRecognizer(target: self, action: #selector(onLongPressGestureRecognized))
    }()

    private lazy var emptyHeader = EmptyHeader(icon: "libraryHistory", title: .localized(.noHistory), subtitle: .localized(.websitesYouHave))
    var refreshControl: UIRefreshControl?
    var recentlyClosedCell: OneLineTableViewCell?

    // MARK: - Inits

    init(profile: Profile, tabManager: TabManager) {
        self.clearHistoryHelper = ClearHistorySheetProvider(profile: profile, tabManager: tabManager)
        self.viewModel = HistoryPanelViewModel(profile: profile)
        self.profile = profile
        self.state = .history(state: .mainView)

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        browserLog.debug("HistoryPanel Deinitialized.")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        KeyboardHelper.defaultHelper.addDelegate(self)
        viewModel.historyPanelNotifications.forEach {
            NotificationCenter.default.addObserver(self, selector: #selector(handleNotifications), name: $0, object: nil)
        }

        handleRefreshControl()
        setupLayout()
        configureDatasource()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        bottomStackView.isHidden = !viewModel.isSearchInProgress
        fetchDataAndUpdateLayout()
    }

    // MARK: - Private helpers

    private func setupLayout() {
        view.addSubview(tableView)
        view.addSubview(bottomStackView)
        bottomStackView.addArrangedSubview(searchSeparator)
        bottomStackView.addArrangedSubview(searchbar)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),

            bottomStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            bottomStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8)
        ])
    }

    // Reload viewModel data and update layout
    private func fetchDataAndUpdateLayout(animating: Bool = false) {
        // Avoid refreshing if search is in progress
        guard !viewModel.isSearchInProgress else { return }

        viewModel.reloadData { [weak self] success in
            DispatchQueue.main.async {
                self?.applySnapshot(animatingDifferences: animating)
            }
        }
    }

    func updateLayoutForKeyboard() {
        guard let keyboardHeight = keyboardState?.intersectionHeightForView(view),
              keyboardHeight > 0 else {
            bottomStackView.removeKeyboardSpacer()
            return
        }

        let spacerHeight = keyboardHeight - UIConstants.BottomToolbarHeight
        bottomStackView.addKeyboardSpacer(spacerHeight: spacerHeight)
        bottomStackView.isHidden = false
    }

    func shouldDismissOnDone() -> Bool {
        guard state != .history(state: .search) else { return false }

        return true
    }

    // Use to enable/disable the additional history action rows. `HistoryActionablesModel`
    private func setTappableStateAndStyle(with item: AnyHashable, on cell: OneLineTableViewCell) {
        var isEnabled = false

        if let actionableItem = item as? HistoryActionablesModel {
            switch actionableItem.itemIdentity {
            case .clearHistory:
                isEnabled = !viewModel.groupedSites.isEmpty
            case .recentlyClosed:
                isEnabled = viewModel.hasRecentlyClosed
                recentlyClosedCell = cell
            default: break
            }
        }

        // Set interaction behavior and style
        cell.titleLabel.alpha = isEnabled ? 1.0 : 0.5
        cell.leftImageView.alpha = isEnabled ? 1.0 : 0.5
        cell.selectionStyle = isEnabled ? .default : .none
        cell.isUserInteractionEnabled = isEnabled
    }

    // MARK: - Datasource helpers

    func siteAt(indexPath: IndexPath) -> Site? {
        guard let siteItem = diffableDatasource?.itemIdentifier(for: indexPath) as? Site else { return nil }

        return siteItem
    }

    private func showClearRecentHistory() {
        clearHistoryHelper.showClearRecentHistory(onViewController: self) { [weak self] dateOption in

            // Delete groupings that belong to THAT section.
            switch dateOption {
            case .today, .yesterday:
                self?.viewModel.deleteGroupsFor(dateOption: dateOption)
            default:
                self?.viewModel.removeAllData()
            }

            DispatchQueue.main.async {
                self?.applySnapshot()
                self?.tableView.reloadData()
                self?.refreshRecentlyClosedCell()
            }
        }
    }

    private func refreshRecentlyClosedCell() {
        guard let cell = recentlyClosedCell else { return }

        self.setTappableStateAndStyle(
            with: HistoryActionablesModel.activeActionables.first(where: { $0.itemIdentity == .recentlyClosed }),
            on: cell)
    }

    func handleNotifications(_ notification: Notification) {
        switch notification.name {
        case .FirefoxAccountChanged, .PrivateDataClearedHistory:
            viewModel.removeAllData()
            fetchDataAndUpdateLayout(animating: true)

            if profile.hasSyncableAccount() {
                resyncHistory()
            }
            break
        case .DatabaseWasReopened:
            if let dbName = notification.object as? String, dbName == "browser.db" {
                fetchDataAndUpdateLayout(animating: true)
            }
        case .OpenClearRecentHistory:
            if viewModel.isSearchInProgress {
                exitSearchState()
            }

            showClearRecentHistory()
        default:
            // no need to do anything at all
            browserLog.error("Error: Received unexpected notification \(notification.name)")
            break
        }
    }

    // MARK: - UITableViewDataSource

    /// Handles dequeuing the appropriate type of cell when needed.
    private func configureDatasource() {
        diffableDatasource = UITableViewDiffableDataSource<HistoryPanelSections, AnyHashable>(tableView: tableView) { [weak self] (tableView, indexPath, item) -> UITableViewCell? in
            guard let self = self else {
                Logger.browserLogger.error("History Panel - self became nil inside diffableDatasource!")
                return nil
            }

            if let historyActionable = item as? HistoryActionablesModel {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: OneLineTableViewCell.cellIdentifier, for: indexPath) as? OneLineTableViewCell else {
                    self.browserLog.error("History Panel - cannot create OneLineTableViewCell for historyActionable!")
                    return nil
                }

                let actionableCell = self.configureHistoryActionableCell(historyActionable, cell)
                return actionableCell
            }

            if let site = item as? Site {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: TwoLineImageOverlayCell.accessoryUsageReuseIdentifier, for: indexPath) as? TwoLineImageOverlayCell else {
                    self.browserLog.error("History Panel - cannot create TwoLineImageOverlayCell for site!")
                    return nil
                }

                let siteCell = self.configureSiteCell(site, cell)
                return siteCell
            }

            if let searchTermGroup = item as? ASGroup<Site> {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: TwoLineImageOverlayCell.cellIdentifier, for: indexPath) as? TwoLineImageOverlayCell else {
                    self.browserLog.error("History Panel - cannot create TwoLineImageOverlayCell for STG!")
                    return nil
                }

                let asGroupCell = self.configureASGroupCell(searchTermGroup, cell)
                return asGroupCell
            }

            // This should never happen! You will have an empty row!
            return UITableViewCell()
        }
    }

    private func configureHistoryActionableCell(_ historyActionable: HistoryActionablesModel, _ cell: OneLineTableViewCell) -> OneLineTableViewCell {
        cell.titleLabel.text = historyActionable.itemTitle
        cell.leftImageView.image = historyActionable.itemImage
        cell.leftImageView.tintColor = .theme.browser.tint
        cell.leftImageView.backgroundColor = .theme.homePanel.historyHeaderIconsBackground
        cell.accessibilityIdentifier = historyActionable.itemA11yId
        setTappableStateAndStyle(with: historyActionable, on: cell)

        return cell
    }

    private func configureSiteCell(_ site: Site, _ cell: TwoLineImageOverlayCell) -> TwoLineImageOverlayCell {
        cell.titleLabel.text = site.title
        cell.titleLabel.isHidden = site.title.isEmpty
        cell.descriptionLabel.text = site.url
        cell.descriptionLabel.isHidden = false
        cell.leftImageView.layer.borderColor = UX.IconBorderColor.cgColor
        cell.leftImageView.layer.borderWidth = UX.IconBorderWidth
        cell.accessoryView = nil
        getFavIcon(for: site) { [weak cell] image in
            cell?.leftImageView.image = image
            cell?.leftImageView.backgroundColor = UIColor.theme.general.faviconBackground
        }

        return cell
    }

    private func getFavIcon(for site: Site, completion: @escaping (UIImage?) -> Void) {
        siteImageHelper.fetchImageFor(site: site, imageType: .favicon, shouldFallback: false) { image in
            completion(image)
        }
    }

    private func configureASGroupCell(_ asGroup: ASGroup<Site>, _ cell: TwoLineImageOverlayCell) -> TwoLineImageOverlayCell {
        if let groupCount = asGroup.description {
            cell.descriptionLabel.text = groupCount
        }

        cell.titleLabel.text = asGroup.displayTitle
        let imageView = UIImageView(image: chevronImage)
        cell.accessoryView = imageView
        cell.leftImageView.image = UIImage(named: ImageIdentifiers.stackedTabsIcon)?.withTintColor(ThemeManager.shared.currentTheme.colours.iconSecondary)
        cell.leftImageView.backgroundColor = .theme.homePanel.historyHeaderIconsBackground

        return cell
    }

    /// The data source gets populated here for your choice of section.
    func applySnapshot(animatingDifferences: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<HistoryPanelSections, AnyHashable>()

        snapshot.appendSections(viewModel.visibleSections)

        snapshot.sectionIdentifiers.forEach { section in
            if !viewModel.hiddenSections.contains(where: { $0 == section }) {
                snapshot.appendItems(viewModel.groupedSites.itemsForSection(section.rawValue - 1), toSection: section)
            }
        }

        // Insert the ASGroup at the correct spot!
        viewModel.searchTermGroups.forEach { grouping in
            if let groupSection = viewModel.shouldAddGroupToSections(group: grouping) {
                guard let individualItem = grouping.groupedItems.last, let lastVisit = individualItem.latestVisit else { return }

                let groupTimeInterval = TimeInterval.fromMicrosecondTimestamp(lastVisit.date)

                if let groupPlacedAfterItem = (viewModel.groupedSites.itemsForSection(groupSection.rawValue - 1)).first(where: { site in
                    guard let lastVisit = site.latestVisit else { return false }
                    return groupTimeInterval > TimeInterval.fromMicrosecondTimestamp(lastVisit.date)
                }) {
                    // In this case, we have Site items AND a group in the section.
                    snapshot.insertItems([grouping], beforeItem: groupPlacedAfterItem)
                } else {
                    // Looks like this group's the only item in the section
                    snapshot.appendItems([grouping], toSection: groupSection)
                }
            }
        }

        // Insert your fixed first section and data
        if let historySection = snapshot.sectionIdentifiers.first, historySection != .additionalHistoryActions {
            snapshot.insertSections([.additionalHistoryActions], beforeSection: historySection)
        } else {
            snapshot.appendSections([.additionalHistoryActions])
        }
        snapshot.appendItems(viewModel.historyActionables, toSection: .additionalHistoryActions)

        diffableDatasource?.apply(snapshot, animatingDifferences: animatingDifferences, completion: nil)
        updateEmptyPanelState()
    }

    // MARK: - Swipe Action helpers

    func removeHistoryItem(at indexPath: IndexPath) {
        guard let historyItem = diffableDatasource?.itemIdentifier(for: indexPath) else { return }

        viewModel.removeHistoryItems(item: [historyItem], at: indexPath.section)

        if viewModel.isSearchInProgress {
            applySearchSnapshot()
        } else {
            applySnapshot(animatingDifferences: true)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        // For UX consistency, every cell in history panel SHOULD have a trailing action.
        let deleteAction = UIContextualAction(style: .destructive, title: .HistoryPanelDelete) { [weak self] (_, _, completion) in
            guard let self = self else {
                Logger.browserLogger.error("History Panel - self became nil inside SwipeActionConfiguration!")
                completion(false)
                return
            }

            self.removeHistoryItem(at: indexPath)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }

    // MARK: - Empty State helpers

    func updateEmptyPanelState() {
        if viewModel.shouldShowEmptyState(searchText: searchbar.text ?? "") {
            tableView.tableFooterView = emptyHeader
            emptyHeader.applyTheme()
        } else {
            tableView.alwaysBounceVertical = true
            tableView.tableFooterView = nil
        }
    }

    // MARK: - NotificationThemeable

    func applyTheme() {
        updateEmptyPanelState()

        tableView.backgroundColor = .theme.homePanel.panelBackground
        searchbar.barTintColor = tableView.backgroundColor
        searchbar.tintColor = .theme.ecosia.information
        searchbar.searchTextField.backgroundColor = .theme.ecosia.primaryBackground
        searchbar.searchTextField.attributedPlaceholder = placeholder
        searchSeparator.backgroundColor = .theme.ecosia.border

        let searchBarImage = UIImage(named: "search")?.tinted(withColor: .theme.ecosia.secondaryText).createScaled(.init(width: 16, height: 16))
        searchbar.setImage(searchBarImage, for: .search, state: .normal)
        searchbar.setPositionAdjustment(.init(horizontal: 4, vertical: 0), for: .search)

        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.theme.ecosia.primaryText]
        bottomSearchButton.tintColor = .theme.ecosia.primaryText
        bottomDeleteButton.tintColor = .theme.ecosia.warning
        bottomStackView.backgroundColor = tableView.backgroundColor

        tableView.reloadData()
    }
}

// MARK: - UITableViewDelegate related helpers

extension HistoryPanel: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let item = diffableDatasource?.itemIdentifier(for: indexPath) else { return }

        if let site = item as? Site {
            handleSiteItemTapped(site: site)
        }

        if let historyActionable = item as? HistoryActionablesModel {
            handleHistoryActionableTapped(historyActionable: historyActionable)
        }

        if let asGroupItem = item as? ASGroup<Site> {
            handleASGroupItemTapped(asGroupItem: asGroupItem)
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if searchbar.isFirstResponder {
            searchbar.resignFirstResponder()
        }
    }

    private func handleSiteItemTapped(site: Site) {
        guard let url = URL(string: site.url) else {
            browserLog.error("Couldn't navigate to site: \(site.url)")
            return
        }

        libraryPanelDelegate?.libraryPanel(didSelectURL: url, visitType: .typed)

        TelemetryWrapper.recordEvent(category: .action,
                                     method: .tap,
                                     object: .selectedHistoryItem,
                                     value: .historyPanelNonGroupItem,
                                     extras: nil)
    }

    private func handleHistoryActionableTapped(historyActionable: HistoryActionablesModel) {
        updatePanelState(newState: .history(state: .inFolder))

        switch historyActionable.itemIdentity {
        case .clearHistory:
            showClearRecentHistory()
        case .recentlyClosed:
            navigateToRecentlyClosed()
        default: break
        }
    }

    private func handleASGroupItemTapped(asGroupItem: ASGroup<Site>) {
        exitSearchState()
        updatePanelState(newState: .history(state: .inFolder))

        let asGroupListViewModel = SearchGroupedItemsViewModel(asGroup: asGroupItem, presenter: .historyPanel)
        let asGroupListVC = SearchGroupedItemsViewController(viewModel: asGroupListViewModel, profile: profile)
        asGroupListVC.libraryPanelDelegate = libraryPanelDelegate
        asGroupListVC.title = asGroupItem.displayTitle

        TelemetryWrapper.recordEvent(category: .action, method: .navigate, object: .navigateToGroupHistory, value: nil, extras: nil)

        navigationController?.pushViewController(asGroupListVC, animated: true)
    }

    @objc private func sectionHeaderTapped(sender: UIGestureRecognizer) {
        guard let sectionNumber = sender.view?.tag else { return }

        viewModel.collapseSection(sectionIndex: sectionNumber)
        applySnapshot()
        // Needed to refresh the header state
        tableView.reloadData()
    }

    // MARK: - TableView's Header & Footer view
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? SiteTableViewHeader, let actualSection = viewModel.visibleSections[safe: section - 1] {

            header.textLabel?.textColor = .theme.ecosia.secondaryText
            header.contentView.backgroundColor = .clear
            header.textLabel?.text = actualSection.title?.uppercased()
            header.collapsibleImageView.isHidden = false
            header.collapsibleImageView.tintColor = .theme.ecosia.secondaryText
            let isCollapsed = viewModel.isSectionCollapsed(sectionIndex: section - 1)
            header.collapsibleState = isCollapsed ? ExpandButtonState.down : ExpandButtonState.up

            // Configure tap to collapse/expand section
            header.tag = section
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(sectionHeaderTapped(sender:)))
            header.addGestureRecognizer(tapGesture)

            // let historySectionsWithGroups
            _ = viewModel.searchTermGroups.map { group in
                viewModel.groupBelongsToSection(asGroup: group)
            }
        }

    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // First section is for recently closed and its header has no view.
        guard HistoryPanelSections(rawValue: section) != .additionalHistoryActions else { return nil }

        return tableView.dequeueReusableHeaderFooterView(withIdentifier: SiteTableViewHeader.cellIdentifier)
    }

    // viewForHeaderInSection REQUIRES implementing heightForHeaderInSection
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // First section is for recently closed and its header has no height.
        guard HistoryPanelSections(rawValue: section) != .additionalHistoryActions else {
            return 0
        }

        return UX.HeaderHeight
    }
}

/// Refresh controls helpers
extension HistoryPanel {
    private func handleRefreshControl() {
        if profile.hasSyncableAccount() && refreshControl == nil {
            let control = UIRefreshControl()
            control.addTarget(self, action: #selector(onRefreshPulled), for: .valueChanged)
            refreshControl = control
            tableView.refreshControl = control
        } else if !profile.hasSyncableAccount() && refreshControl != nil {
            tableView.refreshControl = nil
            refreshControl = nil
        }
    }

    private func endRefreshing() {
        // Always end refreshing, even if we failed!
        refreshControl?.endRefreshing()

        // Remove the refresh control if the user has logged out in the meantime
        handleRefreshControl()
    }

    private func resyncHistory() {
        /*
        profile.syncManager.syncHistory().uponQueue(.main) { syncResult in
            self.endRefreshing()

            if syncResult.isSuccess {
                self.fetchDataAndUpdateLayout(animating: true)
            }
        }
         */
    }
}

// MARK: - User action helpers
extension HistoryPanel {
    func handleLeftTopButton() {
        updatePanelState(newState: .history(state: .mainView))
    }

    func handleRightTopButton() {
        if state == .history(state: .search) {
            exitSearchState()
            updatePanelState(newState: .history(state: .mainView))
        }
    }

    func bottomSearchButtonAction() {
        TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .searchHistory)
        startSearchState()
    }

    func bottomDeleteButtonAction() {
        // Leave search mode when clearing history
        updatePanelState(newState: .history(state: .mainView))

        TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .deleteHistory)
        // TODO: Yoana remove notification and handle directly
        NotificationCenter.default.post(name: .OpenClearRecentHistory, object: nil)
    }

    // MARK: - User Interactions

    /// When long pressed, a menu appears giving the choice of pinning as a Top Site.
    func pinToTopSites(_ site: Site) {
        profile.history.addPinnedTopSite(site).uponQueue(.main) { result in
            if result.isSuccess {
                SimpleToast().showAlertWithText(.AppMenu.AddPinToShortcutsConfirmMessage, image: .named("action_pin"), bottomContainer: self.view)
            }
        }
    }

    private func navigateToRecentlyClosed() {
        guard viewModel.hasRecentlyClosed else { return }

        let nextController = RecentlyClosedTabsPanel(profile: profile)
        nextController.title = .RecentlyClosedTabsPanelTitle
        nextController.libraryPanelDelegate = libraryPanelDelegate
        nextController.recentlyClosedTabsDelegate = BrowserViewController.foregroundBVC()
        refreshControl?.endRefreshing()
        navigationController?.pushViewController(nextController, animated: true)
    }

    @objc private func onLongPressGestureRecognized(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        guard longPressGestureRecognizer.state == .began else { return }
        let touchPoint = longPressGestureRecognizer.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: touchPoint) else { return }

        if let _ = diffableDatasource?.itemIdentifier(for: indexPath) as? HistoryActionablesModel {
            return
        }
        presentContextMenu(for: indexPath)
    }

    
    @objc private func onRefreshPulled() {
        refreshControl?.beginRefreshing()
        // resyncHistory()
    }
}

extension HistoryPanel: UITableViewDataSourcePrefetching {

    // Happens WAY too often. We should consider fetching the next set when the user HITS the bottom instead.
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        guard !viewModel.isFetchInProgress, indexPaths.contains(where: shouldLoadRow) else { return }

        fetchDataAndUpdateLayout(animating: false)
    }

    func shouldLoadRow(for indexPath: IndexPath) -> Bool {
        guard HistoryPanelSections(rawValue: indexPath.section) != .additionalHistoryActions else { return false }

        return indexPath.row >= viewModel.groupedSites.numberOfItemsForSection(indexPath.section - 1) - historyPanelPrefetchOffset
    }
}
