//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import SwiftUI

/// A bare `AVPlayerLayer` wrapper (no system controls), used for inline round video playback.
struct RoundVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer?.player = player
        view.playerLayer?.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer?.player = player
    }
    
    final class PlayerView: UIView {
        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }
        
        var playerLayer: AVPlayerLayer? {
            layer as? AVPlayerLayer
        }
    }
}
