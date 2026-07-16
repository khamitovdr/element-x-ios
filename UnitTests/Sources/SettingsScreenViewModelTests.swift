//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementX
import Foundation
import Testing

@MainActor
struct SettingsScreenViewModelTests {
    private var viewModel: SettingsScreenViewModelProtocol
    private var context: SettingsScreenViewModelType.Context
    
    init() {
        viewModel = Self.makeViewModel()
        context = viewModel.context
    }
    
    @Test
    func logout() async throws {
        let deferred = deferFulfillment(viewModel.actions) { $0 == .logout }
        context.send(viewAction: .logout)
        try await deferred.fulfill()
    }
    
    @Test
    func reportBug() async throws {
        let deferred = deferFulfillment(viewModel.actions) { $0 == .reportBug }
        context.send(viewAction: .reportBug)
        try await deferred.fulfill()
    }
    
    @Test
    func analytics() async throws {
        let deferred = deferFulfillment(viewModel.actions) { $0 == .analytics }
        context.send(viewAction: .analytics)
        try await deferred.fulfill()
    }
    
    // TG-SKIN: settings is a persistent tab now, so a failed/offline first fetch must not
    // hide the manage-account row for the rest of the session — `.appeared` re-runs it.
    @Test
    func appearedRefetchesAccountProfileURL() async throws {
        let clientProxy = ClientProxyMock(.init(userID: ""))
        clientProxy.accountURLActionClosure = { _ in
            clientProxy.accountURLActionCallsCount == 1 ? nil : URL(string: "https://matrix.org/account")
        }
        let userSession = UserSessionMock(.init(clientProxy: clientProxy))
        let viewModel = SettingsScreenViewModel(userSession: userSession,
                                                appSettings: .volatile(),
                                                isBugReportServiceEnabled: true,
                                                isInSecondaryWindow: false)
        let context = viewModel.context
        
        // Let the init `Task` settle before making any assertions.
        try await Task.sleep(for: .milliseconds(100))
        #expect(context.viewState.accountProfileURL == nil)
        #expect(clientProxy.accountURLActionCallsCount == 1)
        
        let deferred = deferFulfillment(context.observe(\.viewState.accountProfileURL)) { $0 != nil }
        context.send(viewAction: .appeared)
        try await deferred.fulfill()
        
        #expect(context.viewState.accountProfileURL != nil)
        #expect(clientProxy.accountURLActionCallsCount == 2)
    }
    
    // TG-SKIN: tab roots hide the Done button.
    @Test
    func doneButtonHiddenWhenRootOfTab() {
        let viewModel = Self.makeViewModel(hidesDoneButton: true)
        #expect(viewModel.context.viewState.hidesDoneButton)
    }
    
    @Test
    func doneButtonShownByDefault() {
        let viewModel = Self.makeViewModel()
        #expect(!viewModel.context.viewState.hidesDoneButton)
    }
    
    private static func makeViewModel(hidesDoneButton: Bool = false) -> SettingsScreenViewModelProtocol {
        let appSettings = AppSettings.volatile()
        let userSession = UserSessionMock(.init(clientProxy: ClientProxyMock(.init(userID: ""))))
        return SettingsScreenViewModel(userSession: userSession,
                                       appSettings: appSettings,
                                       isBugReportServiceEnabled: true,
                                       isInSecondaryWindow: false,
                                       hidesDoneButton: hidesDoneButton)
    }
}
