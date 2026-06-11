//
//  AudioPlayer.swift
//  Hydrate
//
//  Created by memz233 on 6/10/26.
//

import Combine
import SwiftUI
import Foundation
import NowPlaying
import AVFoundation
import DarockFoundation

@Observable
final class AudioPlayer: MediaSessionRepresentable {
    static let shared = AudioPlayer()
    
    let id: String = UUID().uuidString
    
    let _player: AVPlayer = .init()
    var media: NowPlayingInfo? {
        didSet {
            mediaDidUpdate()
        }
    }
    
    private var _observers: [AnyCancellable] = []
    
    init() {
        if let _latestNowPlaying = try? String(contentsOfFile: NSHomeDirectory() + "/Documents/LatestNowPlaying.json", encoding: .utf8),
           var latestNowPlaying = getJsonData(NowPlayingInfo.self, from: _latestNowPlaying) {
            latestNowPlaying.preventAutoPlaying = true
            self.media = latestNowPlaying
        }
        
        _player.publisher(for: \.timeControlStatus).sink { [weak self] status in
            self?.timeControlStatusDidUpdate(status)
        }.store(in: &_observers)
    }
    
    var artworkBackgroundColors = Array(repeating: Color(uiColor: .darkGray), count: 16)
    var audioDuration: TimeInterval?
    var _playbackState = MediaPlaybackSnapshot.PlaybackState.stopped {
        didSet { _playbackStateUpdateDate = .now }
    }
    private var _playbackStateUpdateDate = Date.now
    var elapsedTime: TimeInterval = 0
    private var mediaSession: MediaSession<AudioPlayer>?
    
    var content: (any MediaContentRepresentable)? {
        guard let media else { return nil }
        return MusicContent(
            id: String(media.sourceWork.id) + media.playFileName,
            songTitle: media.playFileName,
            artistName: media.sourceWork.vas.map { $0.name }.joined(separator: "/"),
            albumName: media.sourceWork.title,
            type: .audio,
            duration: audioDuration != nil ? .finite(audioDuration!) : nil,
            artwork: Artwork(id: String(media.sourceWork.id)) { _ in
                let (data, _) = try await URLSession.shared.data(from: URL(string: media.sourceWork.mainCoverUrl)!)
                return try ArtworkRepresentation(data: data)
            }
        )
    }
    var playbackSnapshot: MediaPlaybackSnapshot? {
        MediaPlaybackSnapshot(
            state: _playbackState,
            elapsedTime: elapsedTime,
            timestamp: _playbackStateUpdateDate
        )
    }
    var commands: [MediaCommand] {[
        .play { self.play() },
        .pause { self.pause() },
        .seekToPosition { [unowned self] time in
            await _player.seek(to: CMTime(seconds: time, preferredTimescale: 60000))
        },
        .seekForward(beginAction: {}) { [unowned self] in
            await _player.seek(
                to: CMTime(seconds: _player.currentTime().seconds + 15, preferredTimescale: 60000),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        },
        .seekBackward(beginAction: {}) { [unowned self] in
            await _player.seek(
                to: CMTime(seconds: _player.currentTime().seconds - 15, preferredTimescale: 60000),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }
    ]}
    
    var isPlaying: Bool {
        if case .playing(_) = _playbackState {
            true
        } else {
            false
        }
    }
    var isStarred: Bool {
        get {
            if let media {
                return media.sourceWork.userRating != nil
            } else {
                return false
            }
        }
        set {
            media?.sourceWork.userRating = newValue ? 5 : nil
        }
    }
    var currentTime: TimeInterval {
        _player.currentTime().seconds
    }
    
    func play() {
        _activateMediaSessionIfNeeded()
        _playbackState = .buffering
        _player.play()
    }
    func pause() {
        _player.pause()
    }
    func seek(to time: TimeInterval) {
        _player.seek(to: CMTime(seconds: time, preferredTimescale: 60000))
        elapsedTime = time
    }
    
    func _activateMediaSessionIfNeeded() {
        guard mediaSession == nil else { return }
        
        Task {
            self.mediaSession = MediaSession(self)
            try? await self.mediaSession?.requestToBecomeApplicationPrimary()
            try? await self.mediaSession?.requestToBecomeSystemPrimary()
        }
    }
    func _deactivateMediaSession() {
        self.mediaSession = nil
    }
    
    private func mediaDidUpdate() {
        guard let media else { return }
        
        let newItem = AVPlayerItem(url: URL(string: media.playURL)!)
        _player.replaceCurrentItem(with: newItem)
        if !media.preventAutoPlaying {
            try? AVAudioSession.sharedInstance().setActive(true)
            self.play()
        }
        
        audioDuration = nil
        Task {
            audioDuration = try? await newItem.asset.load(.duration).seconds
        }
        
        Task.detached {
            guard let (data, _) = try? await URLSession.shared.data(from: URL(string: media.sourceWork.mainCoverUrl)!) else { return }
            if let image = UIImage(data: data) {
                let colors = ColorThief.getPalette(from: image, colorCount: 16)!.map {
                    Color(red: Double($0.r) / 255, green: Double($0.g) / 255, blue: Double($0.b) / 255)
                }
                await MainActor.run {
                    self.artworkBackgroundColors = colors
                }
            }
        }
        
        if let jsonData = jsonString(from: media) {
            try? jsonData.write(toFile: NSHomeDirectory() + "/Documents/LatestNowPlaying.json", atomically: true, encoding: .utf8)
        }
    }
    private func timeControlStatusDidUpdate(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .paused:
            _playbackState = .paused
        case .waitingToPlayAtSpecifiedRate:
            _playbackState = .buffering
        case .playing:
            _playbackState = .playing(rate: _player.rate)
        @unknown default: break
        }
        elapsedTime = currentTime
    }
}
