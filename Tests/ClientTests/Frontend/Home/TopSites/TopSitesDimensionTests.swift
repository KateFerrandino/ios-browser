// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import XCTest
import Storage

@testable import Client

class TopSitesDimensionTests: XCTestCase {
    struct DeviceSize {
        static let iPhone14 = CGSize(width: 390, height: 844)
        static let iPadAir = CGSize(width: 820, height: 1180)
        static let iPadAirCompactSplit = CGSize(width: 320, height: 375)
    }

    func testSectionDimension_portraitIphone_defaultRowNumber() {
        let sut = createSut()
        let trait = MockTraitCollection().getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: false, isIphone: true, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(), numberOfRows: 2, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 2)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }

    func testSectionDimension_landscapeIphone_defaultRowNumber() {
        let sut = createSut()
        let trait = MockTraitCollection().getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: true, isIphone: true, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(), numberOfRows: 2, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 2)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }

    func testSectionDimension_portraitiPadRegular_defaultRowNumber() {
        let sut = createSut()
        let trait = MockTraitCollection().getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: false, isIphone: false, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(), numberOfRows: 2, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 2)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }

    func testSectionDimension_landscapeiPadRegular_defaultRowNumber() {
        let sut = createSut()
        let trait = MockTraitCollection().getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: true, isIphone: false, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(), numberOfRows: 2, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 2)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }

    func testSectionDimension_portraitiPadCompact_defaultRowNumber() {
        let sut = createSut()
        let trait = MockTraitCollection(horizontalSizeClass: .compact).getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: false, isIphone: false, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(), numberOfRows: 2, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 2)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }

    func testSectionDimension_landscapeiPadCompact_defaultRowNumber() {
        let sut = createSut()
        let trait = MockTraitCollection(horizontalSizeClass: .compact).getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: true, isIphone: false, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(), numberOfRows: 2, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 2)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }

    func testSectionDimension_portraitiPadUnspecified_defaultRowNumber() {
        let sut = createSut()
        let trait = MockTraitCollection(horizontalSizeClass: .unspecified).getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: false, isIphone: false, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(), numberOfRows: 2, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 2)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }

    func testSectionDimension_landscapeiPadUnspecified_defaultRowNumber() {
        let sut = createSut()
        let trait = MockTraitCollection(horizontalSizeClass: .unspecified).getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: true, isIphone: false, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(), numberOfRows: 2, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 2)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }

    // MARK: Section dimension with stubbed data

    func testSectionDimension_oneEmptyRow_shouldBeRemoved() {
        let sut = createSut()
        let trait = MockTraitCollection().getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: false, isIphone: true, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(count: 4), numberOfRows: 2, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 1)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }

    func testSectionDimension_twoEmptyRow_shouldBeRemoved() {
        let sut = createSut()
        let trait = MockTraitCollection().getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: false, isIphone: true, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(count: 4), numberOfRows: 3, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 1)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }

    func testSectionDimension_noEmptyRow_shouldNotBeRemoved() {
        let sut = createSut()
        let trait = MockTraitCollection().getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: false, isIphone: true, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(count: 8), numberOfRows: 2, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 2)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }

    func testSectionDimension_halfFilledRow_shouldNotBeRemoved() {
        let sut = createSut()
        let trait = MockTraitCollection().getTraitCollection()
        let interface = TopSitesUIInterface(isLandscape: false, isIphone: true, trait: trait)

        let dimension = sut.getSectionDimension(for: createSites(count: 6), numberOfRows: 2, interface: interface)
        XCTAssertEqual(dimension.numberOfRows, 2)
        XCTAssertEqual(dimension.numberOfTilesPerRow, 4)
    }
}

extension TopSitesDimensionTests {
    func createSut() -> TopSitesDimension {
        let sut = TopSitesDimensionImplementation()
        trackForMemoryLeaks(sut)

        return sut
    }

    func createSites(count: Int = 30) -> [TopSite] {
        var sites = [TopSite]()
        (0..<count).forEach {
            let site = Site(url: "www.url\($0).com",
                            title: "Title \($0)")
            sites.append(TopSite(site: site))
        }
        return sites
    }
}
