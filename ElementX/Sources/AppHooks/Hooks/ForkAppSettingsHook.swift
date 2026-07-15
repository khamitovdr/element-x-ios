//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Fork customisation: pins login to the private homeserver and forces
/// off the feature flags for functionality this fork doesn't ship.
/// See docs/fork-slimming.md.
struct ForkAppSettingsHook: AppSettingsHookProtocol {
    /// The only account provider offered at login. Change the server here.
    static let accountProviders = ["branga.ru"]
    
    func configure(_ appSettings: AppSettings) -> AppSettings {
        appSettings.override(accountProviders: Self.accountProviders,
                             allowOtherAccountProviders: false,
                             hideBrandChrome: appSettings.hideBrandChrome,
                             pushGatewayBaseURL: appSettings.pushGatewayBaseURL,
                             oAuthRedirectURL: appSettings.oAuthRedirectURL,
                             websiteURL: appSettings.websiteURL,
                             logoURL: appSettings.logoURL,
                             copyrightURL: appSettings.copyrightURL,
                             acceptableUseURL: appSettings.acceptableUseURL,
                             privacyURL: appSettings.privacyURL,
                             encryptionURL: appSettings.encryptionURL,
                             deviceVerificationURL: appSettings.deviceVerificationURL,
                             chatBackupDetailsURL: appSettings.chatBackupDetailsURL,
                             identityPinningViolationDetailsURL: appSettings.identityPinningViolationDetailsURL,
                             historySharingDetailsURL: appSettings.historySharingDetailsURL,
                             elementWebHosts: appSettings.elementWebHosts,
                             accountProvisioningHost: appSettings.accountProvisioningHost,
                             bugReportApplicationID: appSettings.bugReportApplicationID,
                             analyticsTermsURL: appSettings.analyticsTermsURL,
                             mapTilerConfiguration: AppSettings.bundledMapTilerConfiguration)
        
        // Idempotent: wins over any stale persisted Labs/Developer-Options toggles.
        appSettings.threadsEnabled = false
        appSettings.roomThreadListEnabled = false
        appSettings.knockingEnabled = false
        appSettings.linkNewDeviceEnabled = false
        
        return appSettings
    }
}
