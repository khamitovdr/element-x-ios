//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import CryptoKit
import Foundation

/// Fork: Sentry removed — see docs/fork-slimming.md. Kept as a no-op so
/// analytics call sites throughout the app remain untouched.
class Signposter {
    enum TransactionName: Hashable {
        case cachedRoomList
        case upToDateRoomList
        case notificationToMessage
        case openRoom
        case sendMessage(uuid: String)
        
        var id: String {
            switch self {
            case .cachedRoomList:
                "Cached room list"
            case .upToDateRoomList:
                "Up-to-date room list"
            case .notificationToMessage:
                "Notification to message"
            case .openRoom:
                "Open a room"
            case .sendMessage:
                "Send a message"
            }
        }
    }
    
    enum SpanName: String {
        case timelineLoad = "Timeline load"
    }
    
    struct Span {
        func finish() { }
    }
    
    enum TagName: String {
        case homeserver
    }
    
    // MARK: - Transactions
    
    func startTransaction(_ transactionName: TransactionName, operation: String = "ux", tags: [TagName: String] = [:]) { }
    
    func finishTransaction(_ transactionName: TransactionName) { }
    
    func resetTransactions() { }
    
    // MARK: - Spans
    
    func addSpan(_ spanName: SpanName, toTransaction transactionName: TransactionName) -> Span? {
        Span()
    }
    
    // MARK: - Tags
    
    func addGlobalTag(_ tagName: TagName, value: String) { }
    
    func removeGlobalTag(_ tagName: TagName) { }
    
    // MARK: - Private
    
    func sha512(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA512.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
