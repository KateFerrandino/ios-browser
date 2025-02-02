// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit
import Storage

struct SiteTableViewControllerUX {
    static let HeaderHeight = CGFloat(32)
    static let RowHeight = CGFloat(44)
    static let HeaderFont = UIFont.preferredFont(forTextStyle: .caption1)
    static let HeaderTextMargin = CGFloat(16)
}

class SiteTableViewHeader: UITableViewHeaderFooterView, NotificationThemeable, ReusableCell {

    var collapsibleState: ExpandButtonState? {
        willSet(state) {
            collapsibleImageView.image = state?.image
        }
    }

    let titleLabel: UILabel = .build { label in
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = UIColor.theme.ecosia.secondaryText
    }

    let headerActionButton: UIButton = .build { button in
        button.setTitle("Show all", for: .normal)
        button.backgroundColor = .clear
        button.titleLabel?.font = .systemFont(ofSize: 12)
        button.isHidden = true
    }

    let collapsibleImageView: UIImageView = .build { imageView in
        imageView.image = ExpandButtonState.down.image
        imageView.isHidden = true
    }

    fileprivate let bordersHelper = ThemedHeaderFooterViewBordersHelper()

    override var textLabel: UILabel? {
        return titleLabel
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        contentView.addSubviews(titleLabel, headerActionButton)
        contentView.addSubviews(titleLabel, collapsibleImageView)

        bordersHelper.initBorders(view: self.contentView)
        setDefaultBordersValues()

        backgroundView = UIView()

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: CGFloat(SiteTableViewControllerUX.HeaderTextMargin)),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8, priority: .defaultHigh),

            collapsibleImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            collapsibleImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            headerActionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            headerActionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
        ])

        applyTheme()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setDefaultBordersValues()
        applyTheme()
    }

    func applyTheme() {
        titleLabel.textColor = UIColor.theme.ecosia.secondaryText
        contentView.backgroundColor = .clear
        bordersHelper.applyTheme()
    }

    func showBorder(for location: ThemedHeaderFooterViewBordersHelper.BorderLocation, _ show: Bool) {
        bordersHelper.showBorder(for: location, show)
    }

    func setDefaultBordersValues() {
        bordersHelper.showBorder(for: .top, false)
        bordersHelper.showBorder(for: .bottom, false)
    }
}

/**
 * Provides base shared functionality for site rows and headers.
 */
@objcMembers
class SiteTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NotificationThemeable {
    let CellIdentifier = "CellIdentifier"
    let OneLineCellIdentifier = "OneLineCellIdentifier"
    let HeaderIdentifier = "HeaderIdentifier"
    let profile: Profile
    // Ecosia: Branding
    let style: UITableView.Style

    var data: Cursor<Site> = Cursor<Site>(status: .success, msg: "No data set")
    lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: self.style)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.delegate = self
        table.dataSource = self
        table.register(TwoLineImageOverlayCell.self, forCellReuseIdentifier: self.CellIdentifier)
        table.register(OneLineTableViewCell.self, forCellReuseIdentifier: self.OneLineCellIdentifier)
        table.register(SiteTableViewHeader.self, forHeaderFooterViewReuseIdentifier: self.HeaderIdentifier)
        // Ecosia: table.layoutMargins = .zero
        table.keyboardDismissMode = .onDrag
        table.accessibilityIdentifier = "SiteTable"
        table.cellLayoutMarginsFollowReadableWidth = false
        table.estimatedRowHeight = SiteTableViewControllerUX.RowHeight
        table.setEditing(false, animated: false)
        if style == .insetGrouped {
            table.contentInset.top = 24
        }

        if let _ = self as? LibraryPanelContextMenu {
            table.dragDelegate = self
        }

        // Set an empty footer to prevent empty cells from appearing in the list.
        table.tableFooterView = UIView()

        if #available(iOS 15.0, *) {
            table.sectionHeaderTopPadding = 0
        }
        return table
    }()

    private override init(nibName: String?, bundle: Bundle?) {
        fatalError("init(coder:) has not been implemented")
    }

    init(profile: Profile, style: UITableView.Style = .insetGrouped) {
        self.profile = profile
        self.style = style
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
    }

    deinit {
        // The view might outlive this view controller thanks to animations;
        // explicitly nil out its references to us to avoid crashes. Bug 1218826.
        tableView.dataSource = nil
        tableView.delegate = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reloadData()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        tableView.setEditing(false, animated: false)
        // The AS context menu does not behave correctly. Dismiss it when rotating.
        if let _ = self.presentedViewController as? PhotonActionSheet {
            self.presentedViewController?.dismiss(animated: true, completion: nil)
        }
    }

    private func setupView() {
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        applyTheme()
    }

    func reloadData() {
        if data.status != .success {
            print("Err: \(data.statusMessage)", terminator: "\n")
        } else {
            self.tableView.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier, for: indexPath)
        if self.tableView(tableView, hasFullWidthSeparatorForRowAtIndexPath: indexPath) {
            cell.separatorInset = .zero
        }
        cell.textLabel?.textColor = UIColor.theme.tableView.rowText
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return tableView.dequeueReusableHeaderFooterView(withIdentifier: HeaderIdentifier)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = UIColor.theme.ecosia.secondaryText
            header.contentView.backgroundColor = .clear
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return SiteTableViewControllerUX.HeaderHeight
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, hasFullWidthSeparatorForRowAtIndexPath indexPath: IndexPath) -> Bool {
        return false
    }

    func applyTheme() {
        navigationController?.navigationBar.barTintColor = UIColor.theme.ecosia.barBackground
        navigationController?.navigationBar.tintColor = UIColor.theme.general.controlTint
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.headerTextDark]
        setNeedsStatusBarAppearanceUpdate()

        tableView.backgroundColor = UIColor.theme.homePanel.panelBackground
        tableView.separatorColor = UIColor.theme.ecosia.border
        if let rows = tableView.indexPathsForVisibleRows {
            IndexSet(rows.map { $0.section }).forEach {
                (tableView.headerView(forSection: $0) as? NotificationThemeable)?.applyTheme()
                (tableView.footerView(forSection: $0) as? NotificationThemeable)?.applyTheme()
            }
            rows.forEach {
                (tableView.cellForRow(at: $0) as? NotificationThemeable)?.applyTheme()
            }
        }
    }
}

extension SiteTableViewController: UITableViewDragDelegate {

    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let panelVC = self as? LibraryPanelContextMenu,
              let site = panelVC.getSiteDetails(for: indexPath),
              let url = URL(string: site.url), let itemProvider = NSItemProvider(contentsOf: url)
        else { return [] }

        // Telemetry is being sent to legacy, need to add it to metrics.yml
        // Value should be something else than .homePanel
        TelemetryWrapper.recordEvent(category: .action, method: .drag, object: .url, value: .homePanel)

        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = site
        return [dragItem]
    }

    func tableView(_ tableView: UITableView, dragSessionWillBegin session: UIDragSession) {
        presentedViewController?.dismiss(animated: true)
    }
}
