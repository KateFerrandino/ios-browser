/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Core

protocol EcosiaHomeDelegate: AnyObject {
    func ecosiaHome(didSelectURL url: URL)
}

final class EcosiaHome: UICollectionViewController, UICollectionViewDelegateFlowLayout, Themeable, MyImpactStackViewModelResize {

    enum Section: Int, CaseIterable {
        case impact, legacyImpact, multiply, news, explore

        var cell: AnyClass {
            switch self {
            case .impact: return MyImpactCell.self
            case .legacyImpact: return TreesCell.self
            case .multiply: return MultiplyImpactCell.self
            case .explore: return EcosiaExploreCell.self
            case .news: return NewsCell.self
            }
        }

        var sectionTitle: String? {
            if self == .explore { return .localized(.exploreEcosia) }
            if self == .news { return .localized(.stories) }
            return nil
        }

        enum Explore: Int, CaseIterable {
            case info, finance, trees, faq, shop, privacy

            var title: String {
                switch self {
                case .info:
                    return .localized(.howEcosiaWorks)
                case .finance:
                    return .localized(.financialReports)
                case .trees:
                    return .localized(.trees)
                case .faq:
                    return .localized(.faq)
                case .shop:
                    return .localized(.shop)
                case .privacy:
                    return .localized(.privacy)
                }
            }

            var image: String {
                switch self {
                case .info:
                    return "networkTree"
                case .finance:
                    return "reports"
                case .trees:
                    return "treesIcon"
                case .faq:
                    return "faqIcon"
                case .shop:
                    return "shopIcon"
                case .privacy:
                    return "tigerIncognito"
                }
            }

            var url: URL {
                switch self {
                case .info:
                    return Environment.current.howEcosiaWorks
                case .finance:
                    return Environment.current.financialReports
                case .trees:
                    return Environment.current.trees
                case .faq:
                    return Environment.current.faq
                case .shop:
                    return Environment.current.shop
                case .privacy:
                    return Environment.current.privacy
                }
            }

            var label: Analytics.Label.Navigation {
                switch self {
                case .info:
                    return .howEcosiaWorks
                case .finance:
                    return .financialReports
                case .trees:
                    return .projects
                case .faq:
                    return .faq
                case .shop:
                    return .shop
                case .privacy:
                    return .privacy
                }
            }
        }
    }

    var delegate: EcosiaHomeDelegate?
    private var items = [NewsModel]()
    private let images = Images(.init(configuration: .ephemeral))
    private let news = News()
    private let personalCounter = PersonalCounter()
    private let referrals = Referrals()

    lazy var impactModel: MyImpactCellModel = {
        return refreshImpactModel()
    }()

    private func refreshImpactModel() -> MyImpactCellModel {
        return referralImpactCellModel
    }

    private var referralImpactCellModel: MyImpactCellModel {
        let callout = MyImpactCellModel.Callout(text: .localized(.myImpactDescription),
                                                button: .localized(.learnMore),
                                                selector: #selector(learnMore),
                                                collapsed: true)
        let top = MyImpactStackViewModel(title: "\(User.shared.impact)",
                                         highlight: true, subtitle: .localized(.myTrees),
                                         imageName: "personalCounter")

        let middle = MyImpactStackViewModel(title: .localizedPlural(.treesPlural, num: User.shared.searchImpact),
                                            highlight: false,
                                            subtitle: .localizedPlural(.searches, num: personalCounter.state!),
                                            imageName: "impactSearch")

        let bottom = MyImpactStackViewModel(title: .localizedPlural(.treesPlural, num: User.shared.referrals.impact),
                                            highlight: false,
                                            subtitle: .localizedPlural(.referrals, num: User.shared.referrals.count),
                                            imageName: "impactReferrals")

        return MyImpactCellModel(top: top, middle: middle, bottom: bottom, callout: callout)
    }

    fileprivate var treesCellModel: TreesCellModel {
        return .init(title: .localizedPlural(.searches, num: personalCounter.state!),
                     subtitle: .localized(.onAverageItTakes),
                     highlight: nil,
                     spotlight: nil)
    }

    convenience init(delegate: EcosiaHomeDelegate?) {
        let layout = EcosiaHomeLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 16
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.footerReferenceSize = .zero
        layout.headerReferenceSize = .zero
        self.init(collectionViewLayout: layout)
        self.title = .localized(.myImpact).capitalized
        self.delegate = delegate
        navigationItem.largeTitleDisplayMode = .always
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let done = UIBarButtonItem(barButtonSystemItem: .done) { [ weak self ] _ in
            self?.dismiss(animated: true, completion: nil)
        }
        navigationItem.rightBarButtonItem = done

        Section.allCases.forEach {
            collectionView!.register($0.cell, forCellWithReuseIdentifier: String(describing: $0.cell))
        }
        collectionView!.register(HeaderCell.self, forCellWithReuseIdentifier: .init(describing: HeaderCell.self))
        collectionView.register(MoreButtonCell.self, forCellWithReuseIdentifier: .init(describing: MoreButtonCell.self))
        collectionView.delegate = self
        collectionView.contentInsetAdjustmentBehavior = .scrollableAxes

        NotificationCenter.default.addObserver(self, selector: #selector(updateLayout), name: UIDevice.orientationDidChangeNotification, object: nil)

        applyTheme()

        news.subscribeAndReceive(self) { [weak self] in
            self?.items = $0
            self?.collectionView.reloadSections([Section.news.rawValue])
        }

        personalCounter.subscribe(self)  { [weak self] _ in
            guard let self = self else { return }
            self.impactModel = self.refreshImpactModel()
            self.collectionView.reloadSections([Section.impact.rawValue, Section.legacyImpact.rawValue])
        }

        referrals.subscribe(self)  { [weak self] _ in
            guard let self = self else { return }
            self.impactModel = self.refreshImpactModel()
            self.collectionView.reloadSections([Section.impact.rawValue])
        }
    }

    private var hasAppeared: Bool = false
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        news.load(session: .shared, force: items.isEmpty)
        Analytics.shared.navigation(.view, label: .home)
        guard hasAppeared else { return hasAppeared = true }
        updateBarAppearance()
        impactModel = refreshImpactModel()
        collectionView.scrollRectToVisible(.init(x: 0, y: 0, width: 1, height: 1), animated: false)
        collectionView.reloadData()
    }

    // MARK: UICollectionViewDataSource
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return Section.allCases.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .impact: return Referrals.isEnabled ? 1 : 0
        case .legacyImpact: return Referrals.isEnabled ? 0 : 1
        case .multiply: return Referrals.isEnabled ? 1 : 0
        case .explore: return Section.Explore.allCases.count + 1 // header
        case .news: return min(3, items.count) + 2 // header and footer
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let section = Section(rawValue: indexPath.section)!

        switch  section {
        case .impact:
            let infoCell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: section.cell), for: indexPath) as! MyImpactCell
            infoCell.setWidth(collectionView.bounds.width, insets: collectionView.safeAreaInsets)
            infoCell.display(impactModel)
            return infoCell

        case .legacyImpact:
            let treesCell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: section.cell), for: indexPath) as! TreesCell
            treesCell.display(treesCellModel)
            treesCell.setWidth(collectionView.bounds.width, insets: collectionView.safeAreaInsets)
            return treesCell

        case .multiply:
            let multiplyCell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: section.cell), for: indexPath) as! MultiplyImpactCell
            multiplyCell.setWidth(collectionView.bounds.width, insets: collectionView.safeAreaInsets)
            let model = MyImpactStackViewModel(title: nil,
                                               highlight: false,
                                               subtitle: .localized(.multiplyImpact),
                                               imageName: nil)
            multiplyCell.display(model, action: .tap(text: .localized(.inviteFriends)))
            return multiplyCell
        case .explore:
            if indexPath.row == 0 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: .init(describing: HeaderCell.self), for: indexPath) as! HeaderCell
                cell.titleLabel.text = section.sectionTitle
                cell.setWidth(collectionView.bounds.width, insets: collectionView.safeAreaInsets)
                return cell
            } else {
                let exploreCell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: section.cell), for: indexPath) as! EcosiaExploreCell
                exploreCell.setWidth(collectionView.bounds.width, insets: collectionView.safeAreaInsets)
                Section.Explore(rawValue: indexPath.row - 1).map { exploreCell.display($0) }
                return exploreCell
            }
        case .news:
            if indexPath.row == 0 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: .init(describing: HeaderCell.self), for: indexPath) as! HeaderCell
                cell.titleLabel.text = section.sectionTitle
                cell.setWidth(collectionView.bounds.width, insets: collectionView.safeAreaInsets)
                return cell
            } else if indexPath.row == self.collectionView(collectionView, numberOfItemsInSection: Section.news.rawValue) - 1 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: .init(describing: MoreButtonCell.self), for: indexPath) as! MoreButtonCell
                cell.moreButton.setTitle(.localized(.more), for: .normal)
                cell.moreButton.addTarget(self, action: #selector(allNews), for: .primaryActionTriggered)
                cell.setWidth(collectionView.bounds.width, insets: collectionView.safeAreaInsets)
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: section.cell), for: indexPath) as! NewsCell
                let itemCount = self.collectionView(collectionView, numberOfItemsInSection: Section.news.rawValue) - 2
                cell.configure(items[indexPath.row - 1], images: images, positions: .derive(row: indexPath.row - 1, items: itemCount))
                cell.setWidth(collectionView.bounds.width, insets: collectionView.safeAreaInsets)
                return cell
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        defer {
            collectionView.deselectItem(at: indexPath, animated: true)
        }

        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .impact:
            if let stack = (collectionView.cellForItem(at: indexPath) as? MyImpactCell)?.topStack {
                resizeStack(sender: stack)
            }
        case .legacyImpact:
            delegate?.ecosiaHome(didSelectURL: Environment.current.aboutCounter)
            dismiss(animated: true, completion: nil)
        case .news:
            let index = indexPath.row - 1
            guard index >= 0, items.count > index else { return }
            delegate?.ecosiaHome(didSelectURL: items[index].targetUrl)
            Analytics.shared.navigationOpenNews(items[index].trackingName)
            dismiss(animated: true, completion: nil)
        case .explore:
            Section.Explore(rawValue: indexPath.row)
                .map {
                    delegate?.ecosiaHome(didSelectURL: $0.url)
                    Analytics.shared.navigation(.open, label: $0.label)
                }
            dismiss(animated: true, completion: nil)
        case .multiply:
            navigationController?.pushViewController(MultiplyImpact(delegate: delegate), animated: true)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let section = Section(rawValue: indexPath.section)!
        let margin = max(16, collectionView.safeAreaInsets.left)

        switch section {
        case .impact, .legacyImpact:
            let dynamicTypeResize = max(UIFont.preferredFont(forTextStyle: .body).pointSize - 17, 0) * 7
            return CGSize(width: view.bounds.width - 2 * margin,
                          height: 226 + dynamicTypeResize)
        case .multiply:
            return CGSize(width: view.bounds.width - 2 * margin, height: 56)
        case .news:
            return CGSize(width: view.bounds.width, height: 130)
        case .explore:
            let horizontalItems: CGFloat = traitCollection.horizontalSizeClass == .compact ? 2 : 3
            var width = (view.bounds.width - (horizontalItems + 1) * margin) / horizontalItems
            width = min(width, 180)
            return CGSize(width: width, height: width + 32)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {

        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .news:
            return 0
        default:
            return 16
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        guard let section = Section(rawValue: section), section == .explore else { return .zero }
        return .init(top: 0, left: max(collectionView.safeAreaInsets.left, 16), bottom: 0, right: max(collectionView.safeAreaInsets.right, 16))
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        showSeparator = scrollView.contentOffset.y + scrollView.adjustedContentInset.top <= 12
    }

    private var showSeparator = false {
        didSet {
            if showSeparator != oldValue {
                updateBarAppearance()
            }
        }
    }

    private func updateBarAppearance() {
        guard #available(iOS 13, *), let appearance = navigationController?.navigationBar.standardAppearance else { return }

        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.theme.ecosia.modalBackground
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.theme.ecosia.highContrastText]
        appearance.titleTextAttributes = [.foregroundColor: UIColor.theme.ecosia.highContrastText]

        if showSeparator {
            appearance.shadowColor = nil
            appearance.shadowImage = nil
        } else {
            appearance.shadowColor = UIColor.theme.ecosia.barSeparator
            appearance.shadowImage = UIImage()
        }
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.setNeedsDisplay()
    }

    @objc private func allNews() {
        let news = NewsController(items: items, delegate: delegate)
        navigationController?.pushViewController(news, animated: true)
        Analytics.shared.navigation(.open, label: .news)
    }

    func applyTheme() {
        collectionView.reloadData()
        view.backgroundColor = UIColor.theme.ecosia.modalBackground
        collectionView.backgroundColor = UIColor.theme.ecosia.modalBackground
        navigationItem.leftBarButtonItem?.tintColor = UIColor.theme.ecosia.primaryToolbar
        updateBarAppearance()
    }

    @objc func updateLayout() {
        collectionView.collectionViewLayout.invalidateLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        updateLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateLayout()
        applyTheme()
    }

    @objc func inviteFriends() {
        navigationController?.pushViewController(MultiplyImpact(delegate: delegate), animated: true)
    }

    @objc func learnMore() {
        delegate?.ecosiaHome(didSelectURL: Environment.current.aboutCounter)
        Analytics.shared.navigation(.open, label: .counter)
        dismiss(animated: true, completion: nil)
    }

    @objc func resizeStack(sender: MyImpactStackView) {
        guard let action = sender.action, case .arrow(let collapsed) = action,
              let cell = collectionView.cellForItem(at: IndexPath(item: 0, section: Section.impact.rawValue)) as? MyImpactCell  else { return }

        impactModel.callout.collapsed = !collapsed
        let updatedModel = impactModel

        collectionView.performBatchUpdates {
            UIView.animate(withDuration: 0.3) {
                cell.display(updatedModel)
            }
        }
    }
}
