//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import CoreLocation
import Foundation

final class LocationAnnotation: NSObject, Identifiable {
    let id: String
    var coordinate: CLLocationCoordinate2D
    var kind: LocationMarkerKind
    
    // MARK: - Setup
    
    init(id: String, coordinate: CLLocationCoordinate2D, kind: LocationMarkerKind) {
        self.id = id
        self.coordinate = coordinate
        self.kind = kind
        super.init()
    }
}
