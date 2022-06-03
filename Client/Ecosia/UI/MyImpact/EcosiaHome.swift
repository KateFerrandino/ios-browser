/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Core

protocol EcosiaHomeDelegate: AnyObject {
    func ecosiaHome(didSelectURL url: URL)
}

final class EcosiaHome: UICollectionViewController, UICollectionViewDelegateFlowLayout, Themeable {
    var delegate: EcosiaHomeDelegate?
    private weak var referrals: Referrals!
    private var items = [NewsModel]()
    private var disclosed: IndexPath?
    private let images = Images(.init(configuration: .ephemeral))
    private let news = News()
    private let personalCounter = PersonalCounter()
    private let background = Background()

    fileprivate var treesCellModel: TreesCellModel {
        return .init(trees: User.shared.searchImpact, searches: personalCounter.state!, style: .impact)
    }

    convenience init(delegate: EcosiaHomeDelegate?, referrals: Referrals) {
        let layout = EcosiaHomeLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 16
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.footerReferenceSize = .zero
        layout.headerReferenceSize = .zero
        
        self.init(collectionViewLayout: layout)
        self.title = .localized(.yourImpact)
        self.delegate = delegate
        self.referrals = referrals
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
            self.collectionView.reloadSections([Section.impact.rawValue, Section.legacyImpact.rawValue])
        }

        referrals.subscribe(self)  { [weak self] _ in
            guard let self = self else { return }
            self.collectionView.reloadSections([Section.impact.rawValue])
        }
    }

    private var disappeared = Date.distantFuture
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        news.load(session: .shared, force: items.isEmpty)
        Analytics.shared.navigation(.view, label: .home)

        if Referrals.isEnabled {
            referrals.refresh(force: true)
        }
        
        User.shared.hideRebrandIntro()

        if #available(iOS 15, *) {
            guard
                let cooldown = Calendar.current.date(byAdding: .second, value: 2, to: disappeared),
                cooldown < .now
            else {
                disappeared = .distantFuture
                return
            }
        } else {
            guard
                let cooldown = Calendar.current.date(byAdding: .second, value: 2, to: disappeared),
                cooldown < .init()
            else {
                disappeared = .distantFuture
                return
            }
        }
        
        updateBarAppearance()
        collectionView.scrollRectToVisible(.init(x: 0, y: 0, width: 1, height: 1), animated: false)
        collectionView.reloadData()
        disappeared = .distantFuture
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if #available(iOS 15, *) {
            disappeared = .now
        } else {
            disappeared = .init()
        }
    }

    // MARK: UICollectionViewDataSource
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .impact: return Referrals.isEnabled ? 1 : 0
        case .legacyImpact: return Referrals.isEnabled ? 0 : 1
        case .multiply: return Referrals.isEnabled ? 2 : 0 // with header
        case .explore: return Section.Explore.allCases.count + 1 // header
        case .news: return min(3, items.count) + 2 // header and footer
        }
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .impact:
            let infoCell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: section.cell), for: indexPath) as! MyImpactCell
            infoCell.howItWorksButton.removeTarget(self, action: nil, for: .touchUpInside)
            infoCell.howItWorksButton.addTarget(self, action: #selector(learnMore), for: .touchUpInside)
            infoCell.update(personalCounter: personalCounter.state ?? 0, progress: User.shared.progress)
            return infoCell

        case .legacyImpact:
            let treesCell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: section.cell), for: indexPath) as! TreesCell
            treesCell.display(treesCellModel)
            return treesCell

        case .multiply:
            if indexPath.row == 0 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: .init(describing: HeaderCell.self), for: indexPath) as! HeaderCell
                cell.title.text = section.title
                return cell
            } else {
                let multiplyCell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: section.cell), for: indexPath) as! MultiplyImpactCell
                return multiplyCell
            }
        case .explore:
            if indexPath.row == 0 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: .init(describing: HeaderCell.self), for: indexPath) as! HeaderCell
                cell.title.text = section.title
                return cell
            } else {
                let exploreCell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: section.cell), for: indexPath) as! EcosiaExploreCell
                exploreCell.learnMore.tag = indexPath.row - 1
                exploreCell.learnMore.removeTarget(self, action: nil, for: .touchUpInside)
                exploreCell.learnMore.addTarget(self, action: #selector(explore(button:)), for: .touchUpInside)
                exploreCell.model = .init(rawValue: indexPath.row - 1)
                return exploreCell
            }
        case .news:
            if indexPath.row == 0 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: .init(describing: HeaderCell.self), for: indexPath) as! HeaderCell
                cell.title.text = section.title
                return cell
            } else if indexPath.row == self.collectionView(collectionView, numberOfItemsInSection: Section.news.rawValue) - 1 {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: .init(describing: MoreButtonCell.self), for: indexPath) as! MoreButtonCell
                cell.button.setTitle(.localized(.seeMoreNews), for: .normal)
                cell.button.addTarget(self, action: #selector(allNews), for: .primaryActionTriggered)
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: section.cell), for: indexPath) as! NewsCell
                let itemCount = self.collectionView(collectionView, numberOfItemsInSection: Section.news.rawValue) - 2
                cell.configure(items[indexPath.row - 1], images: images, positions: .derive(row: indexPath.row - 1, items: itemCount))
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
            break
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
            // Index is off by one as first cell is the header
            guard indexPath.row > 0 else { return }

            collectionView.performBatchUpdates({
                disclosed = disclosed == indexPath ? nil : indexPath
                UIView.animate(withDuration: 0.3) {
                    collectionView.collectionViewLayout.invalidateLayout()
                }
            }) {
                collectionView.scrollToItem(at: indexPath, at: .top, animated: $0)
            }
        case .multiply:
            navigationController?.pushViewController(MultiplyImpact(delegate: delegate, referrals: referrals), animated: true)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let section = Section(rawValue: indexPath.section)!
        let height: CGFloat
        
        switch Section(rawValue: indexPath.section)! {
        case .explore:
            if indexPath == disclosed {
                if let cell = collectionView.cellForItem(at: indexPath) as? EcosiaExploreCell {
                    height = cell.expandedHeight
                } else {
                    disclosed = nil
                    height = section.height
                }
            } else {
                height = section.height
            }
        default:
            height = section.height
        }
        
        return .init(width: collectionView.ecosiaHomeMaxWidth, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {

        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .multiply, .news, .explore:
            return 0
        default:
            return 16
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForSectionAt: Int) -> UIEdgeInsets {
        let vertical = insetForSectionAt == Section.explore.rawValue ? 26 : CGFloat()
        let horizontal = (collectionView.bounds.width - collectionView.ecosiaHomeMaxWidth) / 2
        return .init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
    
    func applyTheme() {
        collectionView.reloadData()
        view.backgroundColor = UIColor.theme.ecosia.modalBackground
        collectionView.backgroundColor = .clear
        background.backgroundColor = .theme.ecosia.modalHeader
        updateBarAppearance()
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        background.inset = max(background.inset, scrollView.adjustedContentInset.top)
        background.offset = scrollView.contentOffset.y
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        updateLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateLayout()
        applyTheme()
    }
    
    private func updateBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .theme.ecosia.modalHeader
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.Dark.Text.primary]
        appearance.titleTextAttributes = [.foregroundColor: UIColor.Dark.Text.primary]
        appearance.shadowColor = UIColor.theme.ecosia.impactSeparator
        appearance.shadowImage = UIImage()
        navigationItem.standardAppearance = appearance

        navigationController?.navigationBar.backgroundColor = .theme.ecosia.modalHeader
        navigationController?.navigationBar.tintColor = .Dark.Text.primary
        collectionView.backgroundView = background
        navigationController?.navigationBar.setNeedsDisplay()
    }
    
    @objc private func allNews() {
        let news = NewsController(items: items, delegate: delegate)
        navigationController?.pushViewController(news, animated: true)
        Analytics.shared.navigation(.open, label: .news)
    }

    @objc private func updateLayout() {
        collectionView.collectionViewLayout.invalidateLayout()
    }

    @objc private func inviteFriends() {
        navigationController?.pushViewController(MultiplyImpact(delegate: delegate, referrals: referrals), animated: true)
    }

    @objc private func learnMore() {
        delegate?.ecosiaHome(didSelectURL: Environment.current.aboutCounter)
        Analytics.shared.navigation(.open, label: .counter)
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func explore(button: UIButton) {
        Section.Explore(rawValue: button.tag)
            .map {
                delegate?.ecosiaHome(didSelectURL: $0.url)
                Analytics.shared.navigation(.open, label: $0.label)
            }
        dismiss(animated: true, completion: nil)
    }
}