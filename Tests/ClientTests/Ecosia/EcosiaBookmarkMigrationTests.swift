/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import XCTest
@testable import Client
@testable import Core
import Shared
import Storage

final class EcosiaBookmarkMigrationTests: ProfileTest {
    // TODO: The expecation is 20 seconds for this test. Needs review. Disabled now.
    func testImportBookmarks() {
        try? FileManager.default.removeItem(at: FileManager.pages)
        Core.User.shared.migrated = false
        Core.Favourites().items = ["https://ecosia.org",
                                   "https://www.guacamole.com",
                                   "schemeless.com",
                                   "error://"]
                                    .map {
                                        URL(string: $0)!
                                    }
                                    .map {
                                        .init(url: $0, title: "")
                                    }
        let expect = expectation(description: "")

        PageStore.queue.async {
            DispatchQueue.main.async {
                self.withTestProfile { profile -> Void in
                    let ecosia = EcosiaImport(profile: profile)
                    ecosia.migrate { _ in
                        DispatchQueue.main.async {
                            profile.places.getBookmarksTree(rootGUID: BookmarkRoots.MobileFolderGUID, recursive: true) >>== { result in
                                guard let bookmarkFolder = result as? BookmarkFolderData else { return }
                                XCTAssertEqual(3, bookmarkFolder.children!.count)
                                try? FileManager.default.removeItem(at: FileManager.favourites)
                                expect.fulfill()
                            }
                            
                            _ = profile.places.forceClose()
                            try? profile.files.remove("profile-test_places.db")
                        }
                    }
                }
            }
        }
        waitForExpectations(timeout: 20)
    }
    
    func testURLString() {
        XCTAssertEqual("https://ecosia.org", Core.Page(url: URL(string: "https://ecosia.org")!, title: "").urlString)
        XCTAssertEqual("https://www.guacamole.com", Core.Page(url: URL(string: "https://www.guacamole.com")!, title: "").urlString)
        XCTAssertEqual("http://schemeless.com", Core.Page(url: URL(string: "schemeless.com")!, title: "").urlString)
        XCTAssertNil(Core.Page(url: URL(string: "error://")!, title: "").urlString)
    }
}

