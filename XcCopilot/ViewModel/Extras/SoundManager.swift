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
    
    func playAscendingTone(forFrequency frequency: tone_frequencies) {
        DispatchQueue.global(qos: .userInteractive).async {
            guard let url = Bundle.main.url(forResource: "1000", withExtension: "m4a") else { return }
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
    
    func playTone(forFrequency frequency: tone_frequencies) {
        DispatchQueue.global(qos: .userInteractive).async {
            print("\(frequency.rawValue).mp3")
            guard let url = Bundle.main.url(forResource: frequency.rawValue, withExtension: "mp3") else { return }
            self.player = try? AVAudioPlayer(contentsOf: url)
            self.player?.play()
        }
    }
    
    enum tone_frequencies: String {
        case twoHzAscend = "2hz_ascend"
        case fourHzAscend = "4hz_ascend"
        case sixHzAscend = "6hz_ascend"
        case twoHzDescend = "2hz_descend"
        case fourHzDescend = "4hz_descend"
        case sixHzDescend = "6hz_descend"
    }
}
