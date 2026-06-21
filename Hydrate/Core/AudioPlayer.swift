//
//  AudioPlayer.swift
//  Hydrate
//
//  Created by memz233 on 6/10/26.
//

import OSLog
import Speech
import Combine
import SwiftUI
import Network
import Foundation
import NowPlaying
import Translation
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
    private let _networkPathMonitor = NWPathMonitor()
    private var isNetworkConstrained = false
    
    init() {
        if let _latestNowPlaying = try? String(contentsOfFile: NSHomeDirectory() + "/Documents/LatestNowPlaying.json", encoding: .utf8),
           var latestNowPlaying = getJsonData(NowPlayingInfo.self, from: _latestNowPlaying) {
            latestNowPlaying.preventAutoPlaying = true
            self.media = latestNowPlaying
        }
        
        _player.publisher(for: \.timeControlStatus).sink { [weak self] status in
            self?.timeControlStatusDidUpdate(status)
        }.store(in: &_observers)
        
        _networkPathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            isNetworkConstrained = path.isConstrained
        }
        _networkPathMonitor.start(queue: .init(
            label: "com.memz233.Hydrate.AudioPlayer.network-monitor",
            qos: .background
        ))
    }
    
    deinit {
        _networkPathMonitor.cancel()
    }
    
    var artworkBackgroundColors = Array(repeating: Color(uiColor: .darkGray), count: 16)
    var audioDuration: TimeInterval?
    var _playbackState = MediaPlaybackSnapshot.PlaybackState.stopped {
        didSet { _playbackStateUpdateDate = .now }
    }
    private var _playbackStateUpdateDate = Date.now
    var elapsedTime: TimeInterval = 0
    private var mediaSession: MediaSession<AudioPlayer>?
    
    @ObservationIgnored
    @AppStorage("AutoTranscribeEnabled") private var autoTranscribeEnabled = false
    @ObservationIgnored
    @AppStorage("TranscriptionTranslationEnabled") private var transcriptionTranslationEnabled = false
    private var transcribingTask: Task<Void, Never>?
    var transcriptions: [Transcription]?
    
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
        transcribingTask?.cancel()
        transcribingTask = nil
        transcriptions = nil
        
        guard let media else { return }
        
        let mediaURL = URL(string: media.playURL)!
        var _urlAssetOptions: [String: Any]?
        if media.playURL.hasSuffix(".data") {
            _urlAssetOptions = [
                AVURLAssetOverrideMIMETypeKey: "audio/mpeg"
            ]
        }
        let asset = AVURLAsset(url: mediaURL, options: _urlAssetOptions)
        let newItem = AVPlayerItem(asset: asset)
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
        
        if media.lyrics == nil && autoTranscribeEnabled {
            transcribingTask = Task { [weak self] in
                guard let self else { return }
                
                transcriptions = []
                let transcriber = await LyricsTranscriber(for: _player)
                let constrained = isNetworkConstrained
                do {
                    if !isNetworkConstrained {
                        try await transcriber.transcribeStream(mediaURL) { [weak self] result in
                            DispatchQueue.main.async {
                                self?._updateTranscription(from: result, constrained: constrained)
                            }
                        }
                    } else {
                        try await transcriber.transcribe { [weak self] result in
                            DispatchQueue.main.async {
                                self?._updateTranscription(from: result, constrained: constrained)
                            }
                        }
                    }
                } catch {
                    os_log(.fault, "Transcriber was interrupted with error: \(error)")
                }
            }
        }
        
        if let jsonData = jsonString(from: media) {
            try? jsonData.write(
                toFile: NSHomeDirectory() + "/Documents/LatestNowPlaying.json",
                atomically: true,
                encoding: .utf8
            )
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
    
    private func _updateTranscription(
        from result: SpeechTranscriber.Result,
        constrained: Bool
    ) {
        let resultID = result.range.start.value.hashValue
        var timeRange: ClosedRange<Double>?
        if !constrained {
            timeRange = result.range.start.seconds...result.range.end.seconds
        }
        if var last = transcriptions?.last,
           last.id == resultID || result.isFinal {
            last.attributedString = result.text
            last.isFinal = result.isFinal
            last._timeRange = timeRange
            // modification requires exclusive access
            if let count = transcriptions?.count {
                transcriptions?[count - 1] = last
                
                if result.isFinal, transcriptionTranslationEnabled {
                    Task {
                        let session = TranslationSession(installedSource: .init(identifier: "ja"), target: nil)
                        if let result = try? await session.translate(last.string) {
                            last.translation = result.targetText
                            transcriptions?[count - 1] = last
                        }
                    }
                }
            }
        } else {
            transcriptions?.append(.init(
                id: resultID,
                attributedString: result.text,
                isFinal: result.isFinal,
                _timeRange: timeRange
            ))
        }
    }
    
    struct Transcription: Identifiable, Hashable {
        let id: Int
        var attributedString: AttributedString
        var isFinal: Bool
        var translation: String?
        
        var _timeRange: ClosedRange<Double>?
        
        var string: String {
            String(attributedString.characters)
        }
    }
}

extension Array<AudioPlayer.Transcription> {
    func asLyrics() -> [ClosedRange<Double>: String]? {
        if contains(where: { $0._timeRange != nil }) {
            return reduce(into: [:]) { partialResult, transcription in
                if let range = transcription._timeRange {
                    partialResult.updateValue(
                        transcription.string,
                        forKey: range
                    )
                }
            }
        } else {
            return nil
        }
    }
}
