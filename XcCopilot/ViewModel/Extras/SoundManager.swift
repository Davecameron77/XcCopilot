//
//  SoundManager.swift
//  XcCopilot
//
//  Created by Dave Cameron on 2024-01-17.
//

import Foundation
import AVKit

class SoundManager {
    static let shared = SoundManager()
    
    var player: AVAudioPlayer?
    
    func playAscendingTone() {
        
        guard let url = Bundle.main.url(forResource: "1000", withExtension: "wav") else { return }
        
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
    
    func playDescendingTone() {
        guard let url = Bundle.main.url(forResource: "200", withExtension: "wav") else { return }
        
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
