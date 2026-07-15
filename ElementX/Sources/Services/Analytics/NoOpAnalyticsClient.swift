//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AnalyticsEvents
import Foundation

/// Fork replacement for PostHogAnalyticsClient — analytics are permanently disabled.
class NoOpAnalyticsClient: AnalyticsClientProtocol {
    var isRunning: Bool {
        false
    }
    
    func start(analyticsConfiguration: AnalyticsConfiguration) { }
    
    func reset() { }
    
    func stop() { }
    
    func capture(_ event: AnalyticsEventProtocol) { }
    
    func screen(_ event: AnalyticsScreenProtocol) { }
    
    func updateUserProperties(_ event: AnalyticsEvent.UserProperties) { }
    
    /// Kept because AppCoordinator calls this on the concrete client type.
    func updateSuperProperties(_ properties: AnalyticsEvent.SuperProperties) { }
}
