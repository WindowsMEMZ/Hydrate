//
//  HydrateApp.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import SwiftUI
import MediaPlayer
import AVFoundation
import DarockFoundation

@main
struct HydrateApp: App {
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    @Environment(\.colorScheme) var colorScheme
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { _ in
            globalAudioPlayer.play()
            return .success
        }
        commandCenter.pauseCommand.addTarget { _ in
            globalAudioPlayer.pause()
            return .success
        }
        commandCenter.skipForwardCommand.addTarget { _ in
            globalAudioPlayer.seek(
                to: CMTime(seconds: globalAudioPlayer.currentTime().seconds + 15, preferredTimescale: 60000),
                toleranceBefore: .zero,
                toleranceAfter: .zero)
            return .success
        }
        commandCenter.skipBackwardCommand.addTarget { _ in
            globalAudioPlayer.seek(
                to: CMTime(seconds: globalAudioPlayer.currentTime().seconds - 15, preferredTimescale: 60000),
                toleranceBefore: .zero,
                toleranceAfter: .zero)
            return .success
        }
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = true
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let time = CMTime(seconds: event.positionTime, preferredTimescale: 60000)
            globalAudioPlayer.seek(to: time) { _ in
                MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = event.positionTime
            }
            return .success
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        if let _latestNowPlaying = try? String(contentsOfFile: NSHomeDirectory() + "/Documents/LatestNowPlaying.json", encoding: .utf8),
           var latestNowPlaying = getJsonData(NowPlayingInfo.self, from: _latestNowPlaying) {
            latestNowPlaying.preventAutoPlaying = true
            nowPlayingMedia.send(latestNowPlaying)
        }
        
        return true
    }
}
