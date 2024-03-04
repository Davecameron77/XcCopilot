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
        
        DispatchQueue.global(qos: .userInteractive).async {
            guard let url = Bundle.main.url(forResource: "1000", withExtension: "wav") else { return }
            self.player = try? AVAudioPlayer(contentsOf: url)
            self.player?.play()
        }
    }
    
    func playDescendingTone() {
        
        DispatchQueue.global(qos: .userInteractive).async {
            guard let url = Bundle.main.url(forResource: "200", withExtension: "wav") else { return }
            
            self.player = try? AVAudioPlayer(contentsOf: url)
            self.player?.play()
        }
    }
}
