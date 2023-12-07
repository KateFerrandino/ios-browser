// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

import Foundation
import Core

struct EngagementServiceExperiment {
    
    private init() {}
    
    static var name: String {
        Unleash.Toggle.Name.brazeEngagementService.rawValue
    }

    static var isEnabled: Bool {
        Unleash.isEnabled(.brazeEngagementService)
    }

    static func minSearches() -> Int {
        let variant = Unleash.getVariant(.brazeEngagementService)
        return minSearches(for: variant)
    }
    
    static var variantName: String {
        return Unleash.getVariant(.brazeEngagementService).name
    }

    private static func minSearches(for variant: Unleash.Variant) -> Int {
        3
    }
}
