//
//  NowPlayingView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import AVKit
import Combine
import SwiftUI
import DarockUI
import Alamofire
import MediaPlayer
import AVFoundation
import NaturalLanguage
import DarockFoundation
import SDWebImageSwiftUI
@_spi(Advanced) import SwiftUIIntrospect

struct NowPlayingView: View {
    @State private var audioPlayer = AudioPlayer.shared
    var body: some View {
        VStack {
            _NowPlayingHeaderView()
            _NowPlayingContentView()
                .mask {
                    LinearGradient(
                        colors: [
                            .black.opacity(0),
                            .black,
                            .black,
                            .black,
                            .black,
                            .black,
                            .black,
                            .black,
                            .black,
                            .black,
                            .black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .ignoresSafeArea(edges: .bottom)
        .environment(\.colorScheme, .dark)
        .presentationBackground {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
                    SIMD2<Float>(0.0, 0.5), SIMD2<Float>(0.45, 0.55), SIMD2<Float>(1.0, 0.5),
                    SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5, 1.0), SIMD2<Float>(1.0, 1.0)
                ],
                colors: audioPlayer.artworkBackgroundColors,
                background: .init(uiColor: .darkGray),
                smoothsColors: true
            )
            .blur(radius: 10, opaque: true)
            .overlay {
                Color.black.opacity(0.5)
            }
            .padding(-2)
        }
        .introspect(.sheet, on: .iOS(.v26...)) { controller in
            controller.perform(
                NSSelectorFromString("_setConfiguration:"),
                with: (NSClassFromString("_UISheetPresentationControllerConfiguration") as! NSObject.Type).value(forKey: "_fullScreenConfiguration")
            )
        }
    }
}

struct _NowPlayingHeaderView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("AccountToken") private var accountToken = ""
    @State private var audioPlayer = AudioPlayer.shared
    var body: some View {
        VStack(spacing: 15) {
            Capsule()
                .fill(Color(UIColor.tertiaryLabel))
                .frame(width: 64, height: 4)
                .centerAligned()
                .allowsHitTesting(false)
            HStack(spacing: 10) {
                if let nowPlayingWork = audioPlayer.media?.sourceWork {
                    WebImage(url: URL(string: nowPlayingWork.mainCoverUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray)
                            .redacted(reason: .placeholder)
                    }
                    .scaledToFill()
                    .frame(width: 75, height: 75)
                    .clipped()
                    .cornerRadius(12)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(nowPlayingWork.title)
                            .font(.system(size: 14, weight: .semibold))
                            .marquee()
                        Menu {
                            ForEach(nowPlayingWork.vas, id: \.self) { va in
                                Button(action: {
                                    performSearchSubject.send("$va:\(va.name)$")
                                    dismiss()
                                }, label: {
                                    Label(va.name, systemImage: "magnifyingglass")
                                })
                            }
                        } label: {
                            Text(nowPlayingWork.vas.map { $0.name }.joined(separator: "/"))
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .opacity(0.6)
                                .marquee()
                        }
                    }
                    .marqueeGroup()
                    if !accountToken.isEmpty {
                        StarButton(isStarred: $audioPlayer.isStarred) {
                            if !audioPlayer.isStarred {
                                requestJSON("https://api.asmr.one/api/review", method: .put, parameters: ["work_id": nowPlayingWork.id, "rating": 5, "review_text": nil, "progress": nil], encoding: JSONEncoding.default, headers: globalRequestHeaders) { _, _ in }
                            } else {
                                requestJSON("https://api.asmr.one/api/review?work_id=\(nowPlayingWork.id)", method: .delete, headers: globalRequestHeaders) { _, _ in }
                            }
                            audioPlayer.isStarred.toggle()
                        }
                    }
                    Menu {
                        nowPlayingWork.contextActions
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .padding(.horizontal, -10)
                }
            }
        }
        .padding()
        .padding(.horizontal, 15)
    }
}

struct _NowPlayingContentView: View {
    @Namespace private var coverScaleNamespace
    @Environment(SceneDelegate.self) private var sceneDelegate
    @State private var audioPlayer = AudioPlayer.shared
    @State private var currentPlaybackTime = AudioPlayer.shared.currentTime
    @State private var currentScrolledId = 0.0
    @State private var visibleLyricIDs: Set<Double> = []
    @State private var isShowingControls = false
    @State private var isProgressDraging = false
    @State private var progressDragingNewTime = AudioPlayer.shared.currentTime
    @State private var controlMenuDismissTimer: Timer?
    @State private var isUserScrolling = false
    @State private var canResetUserScrolling = false
    @State private var isScrollAnimationSet = false
    @State private var lyricScrollProxy: ScrollViewProxy?
    @State private var isVolumeDraging = false
    @State private var volumeView = MPVolumeView()
    @State private var volumeDragingNewValue = Double(AVAudioSession.sharedInstance().outputVolume)
    @State private var volumeObserver: NSKeyValueObservation?
    @State private var bluetoothOutputDevice: AVAudioSessionPortDescription?
    var body: some View {
        VStack {
            if let media = audioPlayer.media {
                ZStack {
                    if let lyrics = media.lyrics, !lyrics.isEmpty {
                        LyricsView(
                            lyrics: lyrics,
                            currentTime: displayedPlaybackTime,
                            isScrubbing: isProgressDraging,
                            onControlsVisibilityChange: setControlsVisible
                        )
                    } else if let transcriptions = audioPlayer.transcriptions {
                        if let lyrics = transcriptions.asLyrics() {
                            LyricsView(
                                lyrics: lyrics,
                                currentTime: displayedPlaybackTime,
                                isScrubbing: isProgressDraging,
                                onControlsVisibilityChange: setControlsVisible
                            )
                        } else {
                            TranscriptionTextView(transcriptions: transcriptions)
                        }
                    } else {
                        Text("文本不可用")
                    }
                    // Audio Controls
                    Group {
                        MeshGradient(
                            width: 3,
                            height: 3,
                            points: [
                                SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
                                SIMD2<Float>(0.0, 0.5), SIMD2<Float>(0.45, 0.55), SIMD2<Float>(1.0, 0.5),
                                SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5, 1.0), SIMD2<Float>(1.0, 1.0)
                            ],
                            colors: audioPlayer.artworkBackgroundColors,
                            background: .init(uiColor: .darkGray),
                            smoothsColors: true
                        )
                        .blur(radius: 10, opaque: true)
                        .overlay {
                            Color.black.opacity(0.5)
                        }
                        .mask {
                            LinearGradient(
                                colors: [
                                    .black.opacity(0),
                                    .black.opacity(0),
                                    .black.opacity(0),
                                    .black.opacity(0),
                                    .black,
                                    .black,
                                    .black,
                                    .black
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .offset(y: areControlsVisible ? 0 : 160)
                        .allowsHitTesting(false)
                        VStack {
                            Spacer()
                            VStack(spacing: areControlsVisible ? 8 : -8) {
                                VStack {
                                    Slider(value: $progressDragingNewTime, in: 0...currentItemTotalTime) { isEditing in
                                        isProgressDraging = isEditing
                                        if !isEditing {
                                            audioPlayer.seek(to: progressDragingNewTime)
                                            currentPlaybackTime = progressDragingNewTime
                                        }
                                    }
                                    .sliderThumbVisibility(.hidden)
                                    .tint(.white)
                                    HStack {
                                        Text(formattedTime(from: displayedPlaybackTime))
                                            .font(.system(size: 11, weight: .semibold))
                                            .monospacedDigit()
                                            .opacity(0.6)
                                        Spacer()
                                        Text(formattedTime(from: currentItemTotalTime))
                                            .font(.system(size: 11, weight: .semibold))
                                            .monospacedDigit()
                                            .opacity(0.6)
                                    }
                                    .padding(.top, -10)
                                }
                                .scaleEffect(isProgressDraging ? 1.05 : 1)
                                .padding(.horizontal, 30)
                                .padding(.bottom, areControlsVisible ? 10 : 2)
                                .animation(.easeOut(duration: 0.2), value: isProgressDraging)
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        audioPlayer.seek(to: audioPlayer.currentTime - 10)
                                        resetMenuDismissTimer()
                                    }, label: {
                                        Image(systemName: "10.arrow.trianglehead.counterclockwise")
                                            .font(.system(size: 30))
                                    })
                                    .buttonStyle(ControlButtonStyle())
                                    .frame(width: 50, height: 50)
                                    Button(action: {
                                        if audioPlayer.isPlaying {
                                            audioPlayer.pause()
                                        } else {
                                            audioPlayer.play()
                                        }
                                        resetMenuDismissTimer()
                                    }, label: {
                                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 45))
                                            .contentTransition(.symbolEffect(.replace.downUp, options: .speed(4)))
                                    })
                                    .buttonStyle(ControlButtonStyle())
                                    .frame(width: 75, height: 75)
                                    .padding(.horizontal, 40)
                                    Button(action: {
                                        audioPlayer.seek(to: audioPlayer.currentTime + 10)
                                        resetMenuDismissTimer()
                                    }, label: {
                                        Image(systemName: "10.arrow.trianglehead.clockwise")
                                            .font(.system(size: 30))
                                    })
                                    .buttonStyle(ControlButtonStyle())
                                    .frame(width: 50, height: 50)
                                    Spacer()
                                }
                                .padding(.horizontal, 5)
                                .padding(.bottom, areControlsVisible ? 26 : 4)
                                HStack {
                                    Image(systemName: "speaker.fill")
                                        .font(.system(size: 14))
                                        .opacity(0.6)
                                    Slider(value: systemVolumeBinding) { isEditing in
                                        isVolumeDraging = isEditing
                                    }
                                    .sliderThumbVisibility(.hidden)
                                    .tint(.white)
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.system(size: 14))
                                        .opacity(0.6)
                                }
                                .scaleEffect(isVolumeDraging ? 1.05 : 1)
                                .padding(.horizontal, 40)
                                .padding(.bottom, 8)
                                .animation(.easeOut(duration: 0.2), value: isVolumeDraging)
                                HStack {
                                    Spacer()
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: 35, height: 30)
                                    Spacer()
                                    GenericUIViewRepresentable(view: {
                                        let view = AVRoutePickerView()
                                        view.tintColor = UIColor(white: 1, alpha: 0.6)
                                        view.activeTintColor = UIColor(white: 1, alpha: 0.6)
                                        let customButton = UIButton()
                                        let imageName = bluetoothOutputDevice != nil
                                        ? "airpods.pro" : "airplay.audio"
                                        customButton.setImage(UIImage(
                                            systemName: imageName,
                                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20)
                                        ), for: .normal)
                                        view.setValue(customButton, forKey: "customButton")
                                        return view
                                    }()) { view in
                                        let customButton = UIButton()
                                        let imageName = bluetoothOutputDevice != nil
                                        ? "airpods.pro" : "airplay.audio"
                                        customButton.setImage(UIImage(
                                            systemName: imageName,
                                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20)
                                        ), for: .normal)
                                        view.setValue(customButton, forKey: "customButton")
                                    }
                                    .frame(width: 50, height: 30)
                                    Spacer()
                                    Button {
                                        var transaction = Transaction()
                                        transaction.disablesAnimations = true
                                        withTransaction(transaction) {
                                            if audioPlayer.repeatMode == .off {
                                                audioPlayer.repeatMode = .one
                                            } else {
                                                audioPlayer.repeatMode = .off
                                            }
                                        }
                                        resetMenuDismissTimer()
                                    } label: {
                                        if audioPlayer.repeatMode == .off {
                                            Image(systemName: "repeat.1")
                                                .foregroundStyle(.white.opacity(0.6))
                                        } else {
                                            Circle()
                                                .fill(.white.opacity(0.6))
                                                .inversedMask {
                                                    Image(systemName: "repeat.1")
                                                }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 20))
                                    .frame(width: 35, height: 30)
                                    Spacer()
                                }
                                HStack {
                                    Spacer()
                                    Text(bluetoothOutputDevice?.portName ?? "")
                                        .font(.system(size: 11, weight: .semibold))
                                        .lineLimit(1)
                                        .opacity(0.6)
                                    Spacer()
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, 30)
                            .offset(y: areControlsVisible ? 0 : 72)
                        }
                    }
                    .opacity(areControlsVisible ? 1.0 : 0.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: areControlsVisible)
                    .ignoresSafeArea()
                }
                .navigationTitle(media.sourceWork.title)
                .onTapGesture { location in
                    if location.y > sceneDelegate.keyWindowBounds.height / 2 {
                        isShowingControls = true
                        resetMenuDismissTimer()
                    } else {
                        isShowingControls = false
                    }
                }
            } else {
                Text("未在播放")
            }
        }
        .onAppear {
            currentPlaybackTime = audioPlayer.currentTime
            if !isProgressDraging {
                progressDragingNewTime = currentPlaybackTime
            }
            isShowingControls = true
            resetMenuDismissTimer()
            UIApplication.shared.isIdleTimerDisabled = true
            updateSystemVolumeViewVisibility(areControlsVisible)
            volumeObserver = AVAudioSession.sharedInstance().observe(\.outputVolume, options: .new) { _, observedValue in
                guard let newValue = observedValue.newValue else { return }
                
                Task { @MainActor in
                    if !isVolumeDraging {
                        withAnimation(.easeOut(duration: 0.2)) {
                            volumeDragingNewValue = Double(newValue)
                        }
                    }
                }
            }
            updateBluetoothOutputDevice()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            volumeObserver = nil
            volumeView.removeFromSuperview()
        }
        .onChange(of: areControlsVisible) { _, areControlsVisible in
            updateSystemVolumeViewVisibility(areControlsVisible)
        }
        .onChange(of: audioPlayer.isPlaying) { _, isPlaying in
            if isPlaying && areControlsVisible {
                resetMenuDismissTimer()
            } else if !isPlaying {
                controlMenuDismissTimer?.invalidate()
            }
        }
        .onReceive(audioPlayer._player.periodicTimePublisher()) { time in
            // Code in this closure runs at nearly each frame, optimizing for speed is important.
            if time.seconds - currentPlaybackTime >= 0.3 || time.seconds < currentPlaybackTime {
                currentPlaybackTime = time.seconds
                if _fastPath(!isProgressDraging) {
                    progressDragingNewTime = currentPlaybackTime
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { _ in
            updateBluetoothOutputDevice()
        }
    }
    
    var displayedPlaybackTime: TimeInterval {
        isProgressDraging ? progressDragingNewTime : currentPlaybackTime
    }
    var currentItemTotalTime: TimeInterval {
        audioPlayer.audioDuration ?? 0
    }
    var alwaysShowControls: Bool {
        audioPlayer.media?.lyrics == nil
        && audioPlayer.transcriptions?.asLyrics() == nil
    }
    var areControlsVisible: Bool {
        isShowingControls || alwaysShowControls
    }
    var systemVolumeBinding: Binding<Double> {
        Binding {
            volumeDragingNewValue
        } set: { newValue in
            volumeDragingNewValue = newValue
            setSystemVolume(newValue)
        }
    }
    
    private func updateSystemVolumeViewVisibility(_ isVisible: Bool) {
        guard isVisible else {
            volumeView.removeFromSuperview()
            return
        }
        guard let window = sceneDelegate.windowScene?.keyWindow else { return }
        
        if volumeView.superview !== window {
            volumeView.removeFromSuperview()
            volumeView.setVolumeThumbImage(UIImage(), for: .normal)
            volumeView.setVolumeThumbImage(UIImage(), for: .highlighted)
            volumeView.setMinimumVolumeSliderImage(UIImage(), for: .normal)
            volumeView.setMaximumVolumeSliderImage(UIImage(), for: .normal)
            volumeView.frame = CGRect(
                x: 0,
                y: window.bounds.maxY - 1,
                width: window.bounds.width,
                height: 1
            )
            volumeView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
            window.addSubview(volumeView)
            volumeView.layoutIfNeeded()
            
            for routeButton in volumeView.subviews.compactMap({ $0 as? UIButton }) {
                routeButton.isHidden = true
            }
        }
    }
    
    private func setSystemVolume(_ value: Double) {
        guard let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider else {
            return
        }
        
        slider.value = Float(value)
        slider.sendActions(for: .valueChanged)
    }
    
    private func updateBluetoothOutputDevice() {
        let session = AVAudioSession.sharedInstance()
        var didSetNewDevice = false
        for output in session.currentRoute.outputs {
            if output.portType == .bluetoothA2DP
                || output.portType == .bluetoothHFP
                || output.portType == .bluetoothLE {
                bluetoothOutputDevice = output
                didSetNewDevice = true
                break
            }
        }
        if !didSetNewDevice {
            bluetoothOutputDevice = nil
        }
    }
    
    struct WaitingDotsView: View {
        var startTime: Double
        var endTime: Double
        @Binding var currentTime: Double
        @State var dot1Opacity = 0.2
        @State var dot2Opacity = 0.2
        @State var dot3Opacity = 0.2
        @State var scale: CGFloat = 1
        @State var isVisible = false
        @State var verticalPadding: CGFloat = -15
        var body: some View {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white)
                        .opacity(dot1Opacity)
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(Color.white)
                        .opacity(dot2Opacity)
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(Color.white)
                        .opacity(dot3Opacity)
                        .frame(width: 12, height: 12)
                }
                .padding(.horizontal, 5)
                .scaleEffect(scale)
                Spacer(minLength: 5)
            }
            .padding(.vertical, verticalPadding)
            .opacity(isVisible ? 1.0 : kViewMinimumRenderableOpacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever()) {
                    if scale > 1.0 {
                        scale = 1.0
                    } else {
                        scale = 1.2
                    }
                }
            }
            .onChange(of: currentTime) {
                if _fastPath(!isVisible) {
                    isVisible = currentTime >= startTime + 0.2 && currentTime <= endTime
                }
                if currentTime >= startTime && currentTime <= endTime
                    && dot1Opacity == 0.2 && dot2Opacity == 0.2 && dot3Opacity == 0.2 {
                    if #available(watchOS 10, *) {
                        let pieceTime = (endTime - startTime - 1.0) / 3.0
                        withAnimation(.linear(duration: pieceTime)) {
                            dot1Opacity = 1.0
                        } completion: {
                            withAnimation(.linear(duration: pieceTime)) {
                                dot2Opacity = 1.0
                            } completion: {
                                withAnimation(.linear(duration: pieceTime)) {
                                    dot3Opacity = 1.0
                                } completion: {
                                    withAnimation(.easeInOut(duration: 0.6)) {
                                        scale = 1.3
                                    } completion: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            scale = 0.02
                                            dot1Opacity = 0.02
                                            dot2Opacity = 0.02
                                            dot3Opacity = 0.02
                                        } completion: {
                                            isVisible = false
                                            Task {
                                                try? await Task.sleep(for: .seconds(0.5))
                                                dot1Opacity = 0.2
                                                dot2Opacity = 0.2
                                                dot3Opacity = 0.2
                                                scale = 1
                                                withAnimation(.easeInOut(duration: 2.0).repeatForever()) {
                                                    scale = 1.2
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        withAnimation(.linear(duration: endTime - startTime)) {
                            dot1Opacity = 1.0
                            dot2Opacity = 1.0
                            dot3Opacity = 1.0
                        }
                        Task {
                            try? await Task.sleep(for: .seconds(endTime - startTime))
                            isVisible = false
                            try? await Task.sleep(for: .seconds(0.5))
                            dot1Opacity = 0.2
                            dot2Opacity = 0.2
                            dot3Opacity = 0.2
                            scale = 1
                        }
                    }
                }
            }
            .onChange(of: isVisible) {
                if isVisible {
                    withAnimation(.easeOut(duration: 0.3)) {
                        verticalPadding = 0
                    }
                } else {
                    withAnimation(.easeOut) {
                        verticalPadding = -15
                    }
                }
            }
        }
    }
    
    func resetMenuDismissTimer() {
        controlMenuDismissTimer?.invalidate()
        guard audioPlayer.isPlaying else { return }
        
        controlMenuDismissTimer = .scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            Task { @MainActor in
                guard audioPlayer.isPlaying else { return }
                
                if !isProgressDraging && !isVolumeDraging {
                    isShowingControls = false
                } else {
                    resetMenuDismissTimer()
                }
            }
        }
    }
    
    func setControlsVisible(_ isVisible: Bool) {
        isShowingControls = isVisible
        if isVisible {
            resetMenuDismissTimer()
        } else {
            controlMenuDismissTimer?.invalidate()
        }
    }
}

private let _lyricLineSpacing: CGFloat = 26
private let _lyricTopPadding: CGFloat = 80
private let _waitingProgressHeight: CGFloat = 34
private let _controlsVisibilityScrollThreshold: CGFloat = 48
private struct LyricsView: View {
    var lyrics: [ClosedRange<Double>: String]
    var currentTime: Double
    var isScrubbing: Bool
    var onControlsVisibilityChange: (Bool) -> Void
    @AppStorage("TranscriptionTranslationEnabled") private var transcriptionTranslationEnabled = false
    @State private var audioPlayer = AudioPlayer.shared
    @State private var currentIndex: Int
    @State private var lineHeights: [CGFloat] = []
    @State private var pageOffset: CGFloat = 0
    @State private var controlsVisibilityScrollDistance: CGFloat = 0
    @State private var underlyingScrollView: UIScrollView?
    @State private var heightBeforeCurrent: CGFloat = 0
    @State private var isProgrammaticScrolling = false
    @State private var isUserScrolling = false
    @State private var showingFullContent = false
    @State private var canResetShowingFullContent = false
    @State private var isShowingWaitingProgress = false
    @State private var pressedIndex: Int?
    @State private var translations: [String?] = []
    
    init(
        lyrics: [ClosedRange<Double>: String],
        currentTime: Double,
        isScrubbing: Bool,
        onControlsVisibilityChange: @escaping (Bool) -> Void
    ) {
        self.lyrics = lyrics
        self.currentTime = currentTime
        self.isScrubbing = isScrubbing
        self.onControlsVisibilityChange = onControlsVisibilityChange
        
        let lyricKeys = lyrics.keys.sorted {
            $0.lowerBound < $1.lowerBound
        }
        _currentIndex = State(initialValue: lyricKeys.lastIndex {
            $0.lowerBound <= currentTime
        } ?? 0)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            let lyricKeys = Array<ClosedRange<Double>>(lyrics.keys)
                .sorted(by: { lhs, rhs in lhs.lowerBound < rhs.lowerBound })
            
            ScrollView {
                if !lyricKeys.isEmpty, lineHeights.count >= lyrics.count {
                    VStack(spacing: _lyricLineSpacing) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: _lyricTopPadding - _lyricLineSpacing)
                        ForEach(0..<lyricKeys.count, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.clear)
                                .frame(height: lineHeights[index])
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                                ._onButtonGesture { pressing in
                                    if pressing {
                                        pressedIndex = index
                                    } else {
                                        pressedIndex = nil
                                    }
                                } perform: {
                                    pressedIndex = index
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        pressedIndex = nil
                                    }
                                    
                                    selectLyric(
                                        at: index,
                                        time: lyricKeys[index].lowerBound
                                    )
                                }
                            if isShowingWaitingProgress && currentIndex == index {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: _waitingProgressHeight)
                            }
                        }
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 450)
                    }
                    .allowsHitTesting(showingFullContent)
                }
            }
            .introspect(.scrollView, on: .iOS(.v18...)) { scrollView in
                DispatchQueue.main.async {
                    underlyingScrollView = scrollView
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                -geometry.contentOffset.y + heightBeforeCurrent
            } action: { oldValue, newValue in
                guard !isProgrammaticScrolling else { return }
                if isUserScrolling {
                    updateControlsVisibilityScrollDistance(by: newValue - oldValue)
                }
                if abs(pageOffset - newValue) > 0.001 {
                    pageOffset = newValue
                }
            }
            .onScrollPhaseChange { _, newPhase in
                isUserScrolling = newPhase == .tracking
                    || newPhase == .interacting
                    || newPhase == .decelerating
                if !isUserScrolling {
                    controlsVisibilityScrollDistance = 0
                }
                if newPhase == .idle {
                    canResetShowingFullContent = true
                } else {
                    showingFullContent = true
                    canResetShowingFullContent = false
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    if lineHeights.count >= lyrics.count {
                        ForEach(lyricKeys.enumerated(), id: \.offset) { index, range in
                            LineView(
                                range: range,
                                index: index,
                                text: lyrics[range]!,
                                secondaryText: translations.count > index ? translations[index] : nil,
                                currentIndex: currentIndex,
                                pageOffset: pageOffset,
                                pageHeight: geometry.size.height,
                                isPressed: pressedIndex == index,
                                isShowingWaitingProgress: isShowingWaitingProgress,
                                isProgrammaticScrolling: isProgrammaticScrolling,
                                isScrubbing: isScrubbing,
                                lineHeights: $lineHeights,
                                showingFullContent: $showingFullContent,
                                canResetShowingFullContent: $canResetShowingFullContent,
                                beginPageOffsetUpdate: {
                                    prepareForProgrammaticScroll(to: currentIndex)
                                },
                                updatePageOffset: { newOffset in
                                    underlyingScrollView?.contentOffset.y = heightBeforeCurrent - newOffset
                                    pageOffset = newOffset
                                },
                                finishPageOffsetUpdate: {
                                    underlyingScrollView?.contentOffset.y = heightBeforeCurrent
                                    isProgrammaticScrolling = false
                                }
                            )
                        }
                        
                        if currentIndex < lyrics.count - 1 {
                            let waitingRange = lyricKeys[currentIndex].upperBound...lyricKeys[currentIndex + 1].lowerBound
                            let waitingDuration = waitingRange.upperBound - waitingRange.lowerBound
                            let isShowing = waitingDuration > 5 && waitingRange.contains(currentTime)
                            
                            Group {
                                if isShowing {
                                    WaitingProgressView(
                                        range: waitingRange,
                                        currentTime: currentTime,
                                        isScrubbing: isScrubbing
                                    )
                                    .frame(height: _waitingProgressHeight)
                                    .offset(
                                        y: 90 + (
                                            showingFullContent ? pageOffset : 0
                                        )
                                    )
                                    .animation(.spring, value: showingFullContent)
                                    .transition(
                                        .asymmetric(
                                            insertion: .opacity.animation(
                                                .easeInOut(duration: 0.3).delay(0.5)
                                            ),
                                            removal: .opacity.animation(
                                                .easeInOut(duration: 0.3)
                                            )
                                        )
                                    )
                                }
                            }
                            
                            Color.clear
                                .frame(width: 0, height: 0)
                                .onChange(of: isShowing, initial: true) {
                                    isShowingWaitingProgress = isShowing
                                    if isShowing && showingFullContent && canResetShowingFullContent {
                                        canResetShowingFullContent = false
                                        prepareForProgrammaticScroll(to: currentIndex)
                                        showingFullContent = false
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, 30)
                .onChange(of: lyrics.count, initial: true) {
                    lineHeights = .init(repeating: 0, count: lyrics.count)
                    
                    if transcriptionTranslationEnabled {
                        Task {
                            let contents = lyricKeys.map { lyrics[$0]! }
                            if NLLanguageRecognizer.dominantLanguage(for: contents.joined(separator: "\n")) == .japanese {
                                if let results = await LyricTranslation.shared.translate(contents) {
                                    translations = results
                                }
                            }
                        }
                    }
                }
                .onChange(of: currentTime, initial: true) {
                    // During an inter-lyric gap, keep the most recently started
                    // line current instead of falling back to the first line.
                    currentIndex = lyricKeys.lastIndex {
                        $0.lowerBound <= currentTime
                    } ?? 0
                }
                .onChange(of: currentIndex) { oldValue, newValue in
                    updateScrollOffset()
                }
                .onChange(of: isShowingWaitingProgress) {
                    updateScrollOffset()
                }
                .onChange(of: showingFullContent) {
                    if !showingFullContent {
                        updateScrollOffset()
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
    
    private func updateControlsVisibilityScrollDistance(by delta: CGFloat) {
        guard abs(delta) > 0.001 else { return }
        
        if controlsVisibilityScrollDistance * delta < 0 {
            controlsVisibilityScrollDistance = delta
        } else {
            controlsVisibilityScrollDistance += delta
        }
        
        guard abs(controlsVisibilityScrollDistance) >= _controlsVisibilityScrollThreshold else { return }
        onControlsVisibilityChange(controlsVisibilityScrollDistance > 0)
        controlsVisibilityScrollDistance = 0
    }
    
    private func prepareForProgrammaticScroll(to index: Int) {
        guard lineHeights.indices.contains(index) else { return }
        
        var targetHeight = lineHeights[..<index].reduce(into: CGFloat.zero) {
            $0 += $1 + _lyricLineSpacing
        }
        if isShowingWaitingProgress {
            targetHeight += _waitingProgressHeight + _lyricLineSpacing
        }
        
        isProgrammaticScrolling = true
        heightBeforeCurrent = targetHeight
        underlyingScrollView?.contentOffset.y = targetHeight - pageOffset
    }
    
    private func selectLyric(at index: Int, time: Double) {
        guard lineHeights.indices.contains(index) else { return }
        
        isShowingWaitingProgress = false
        prepareForProgrammaticScroll(to: index)
        currentIndex = index
        showingFullContent = false
        
        audioPlayer.seek(to: time)
        audioPlayer.play()
    }
    
    private func updateScrollOffset() {
        guard !showingFullContent else { return }
        
        var heightBeforeCurrent: CGFloat = 0
        if currentIndex > 0 {
            heightBeforeCurrent = lineHeights[0..<currentIndex].reduce(into: 0) {
                $0 += $1 + 26
            }
        }
        if isShowingWaitingProgress {
            heightBeforeCurrent += _waitingProgressHeight + _lyricLineSpacing
        }
        self.heightBeforeCurrent = heightBeforeCurrent
        
        underlyingScrollView?.contentOffset.y = heightBeforeCurrent - pageOffset
    }
    
    private struct LineView: View {
        var range: ClosedRange<Double>
        var index: Int
        var text: String
        var secondaryText: String?
        var currentIndex: Int
        var pageOffset: CGFloat
        var pageHeight: CGFloat
        var isPressed: Bool
        var isShowingWaitingProgress: Bool
        var isProgrammaticScrolling: Bool
        var isScrubbing: Bool
        @Binding var lineHeights: [CGFloat]
        @Binding var showingFullContent: Bool
        @Binding var canResetShowingFullContent: Bool
        var beginPageOffsetUpdate: () -> Void
        var updatePageOffset: (CGFloat) -> Void
        var finishPageOffsetUpdate: () -> Void
        @State private var offset: CGFloat = 0
        @State private var visualPageOffset: CGFloat = 0
        @State private var previousCurrentIndex: Int?
        @State private var isOffsetUpdatePending = false
        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(text)
                        .font(.system(size: 30, weight: .bold))
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: false, vertical: true)
                    if let secondaryText {
                        Text(secondaryText)
                            .font(.system(size: 20, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 10)
            }
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onChange(of: geometry.size.height, initial: true) {
                            if index < lineHeights.count {
                                lineHeights[index] = geometry.size.height
                            }
                        }
                        .onChange(of: lineHeights.count) {
                            if index < lineHeights.count {
                                lineHeights[index] = geometry.size.height
                            }
                        }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray)
                    .opacity(isPressed ? 0.4 : 0)
                    .padding(.horizontal, -10)
                    .padding(.vertical, -5)
            }
            .opacity(isCurrent ? 1 : 0.6)
            .blur(radius: lyricBlurRadius)
            .scaleEffect(isPressed ? 0.95 : 1)
            // Combine the line layout and scroll displacement into one
            // animatable value so a seek retains its on-screen starting position.
            .offset(y: offset + visualPageOffset)
            .opacity( // performance: lazy
                isVisible || isCurrent ? 1 : 0
            )
            .animation(.easeOut(duration: 0.2), value: isPressed)
            .onChange(of: lineHeights) {
                updateOffset()
            }
            .onChange(of: pageOffset, initial: true) { _, newValue in
                if !isProgrammaticScrolling {
                    visualPageOffset = newValue
                }
                if isOffsetUpdatePending && !isOnScreen {
                    isOffsetUpdatePending = false
                    updateOffset()
                }
            }
            .onChange(of: currentIndex) { oldValue, newValue in
                previousCurrentIndex = oldValue
                updateOffset(
                    indexBecomingCurrent: newValue,
                    previousIndex: oldValue
                )
            }
            .onChange(of: isShowingWaitingProgress) { _, isShowing in
                if isShowing {
                    isOffsetUpdatePending = false
                    withAnimation(.smooth) {
                        updateOffset()
                    }
                } else if isProgrammaticScrolling {
                    isOffsetUpdatePending = false
                } else if showingFullContent {
                    if isOnScreen {
                        isOffsetUpdatePending = true
                    } else {
                        updateOffset()
                    }
                } else {
                    updateOffset(indexBecomingCurrent: currentIndex)
                }
            }
            .onChange(of: showingFullContent) {
                if !showingFullContent {
                    isOffsetUpdatePending = false
                    updateOffset(
                        indexBecomingCurrent: currentIndex,
                        previousIndex: previousCurrentIndex
                    )
                }
            }
        }
        
        var isCurrent: Bool {
            (index == currentIndex && !isShowingWaitingProgress)
        }
        var isVisible: Bool {
            -pageOffset < offset + lineHeights[index] * 2
            && -pageOffset + pageHeight > offset - lineHeights[index]
        }
        var isOnScreen: Bool {
            -pageOffset < offset + lineHeights[index]
            && -pageOffset + pageHeight > offset
        }
        var lyricBlurRadius: CGFloat {
            guard isVisible, !showingFullContent, !isCurrent else { return 0 }
            return min(CGFloat(abs(currentIndex - index)), 8)
        }
        
        private func animationDelay(
            becomingCurrent newIndex: Int,
            previousIndex oldIndex: Int?
        ) -> TimeInterval {
            guard !isScrubbing, let oldIndex, oldIndex != newIndex else { return 0 }
            
            // Cascade away from the new current line in the direction of travel.
            // Cap the distance so a long seek never creates a multi-second delay.
            let distance: Int
            if newIndex > oldIndex {
                distance = max(index - newIndex, 0)
            } else {
                distance = max(newIndex - index, 0)
            }
            return min(Double(distance), 6) * 0.045
        }
        
        private func updateOffset(
            indexBecomingCurrent: Int? = nil,
            previousIndex: Int? = nil
        ) {
            var heightBefore: CGFloat = 0
            if index > 0 {
                heightBefore = lineHeights[0..<index].reduce(into: 0) { $0 += $1 }
            }
            
            var heightBeforeCurrent: CGFloat = 0
            if currentIndex > 0 {
                heightBeforeCurrent = lineHeights[0..<currentIndex].reduce(into: 0) {
                    $0 += $1 + _lyricLineSpacing
                }
            }
            
            var waitingProgressOffset: CGFloat = 0
            if isShowingWaitingProgress {
                if index <= currentIndex {
                    waitingProgressOffset = -(
                        lineHeights[currentIndex] + _lyricLineSpacing
                    )
                } else {
                    waitingProgressOffset = -max(
                        lineHeights[currentIndex] - 40,
                        0
                    )
                }
            }
            
            func _update() {
                offset = _lyricTopPadding + heightBefore + CGFloat(index) * _lyricLineSpacing - heightBeforeCurrent + waitingProgressOffset
            }
            
            if let indexBecomingCurrent {
                if index == indexBecomingCurrent
                    && showingFullContent
                    && canResetShowingFullContent
                    && isOnScreen {
                    beginPageOffsetUpdate()
                    canResetShowingFullContent = false
                    showingFullContent = false
                    return // Actual update in next call, by onChange(of: showingFullContent)
                }
                if !showingFullContent {
                    let isTargetLyric = index == indexBecomingCurrent
                    let isNearSelectedLyric = abs(index - indexBecomingCurrent) <= 10
                    if isVisible || (isProgrammaticScrolling && isNearSelectedLyric) {
                        let delay = animationDelay(
                            becomingCurrent: indexBecomingCurrent,
                            previousIndex: previousIndex
                        )
                        if isTargetLyric {
                            // The line offset and page offset form one visual position.
                            // Commit both targets together to avoid an intermediate
                            // downward movement before the line starts moving upward.
                            withAnimation(
                                .spring.delay(delay),
                                completionCriteria: .logicallyComplete
                            ) {
                                updatePageOffset(0)
                                visualPageOffset = 0
                                _update()
                            } completion: {
                                finishPageOffsetUpdate()
                            }
                        } else {
                            withAnimation(.spring.delay(delay)) {
                                visualPageOffset = 0
                                _update()
                            }
                        }
                    } else {
                        visualPageOffset = 0
                        if isTargetLyric {
                            updatePageOffset(0)
                            finishPageOffsetUpdate()
                        }
                        _update()
                    }
                } else {
                    // We don't update offset, as well as underlyingScrollView's
                    // contentOffset, while user is scrolling
                    // (showingFullContent is true).
                }
            } else {
                _update()
            }
        }
    }
}

private struct WaitingProgressView: View {
    let range: ClosedRange<Double>
    let currentTime: Double
    let isScrubbing: Bool
    
    @State private var audioPlayer = AudioPlayer.shared
    
    var body: some View {
        
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 60.0,
                paused: isScrubbing || !audioPlayer.isPlaying
            )
        ) { context in
            let value = progressValue(at: context.date)
            
            VStack(spacing: 4) {
                CustomProgressView(value: value / duration)
                    .frame(height: 15)
                HStack {
                    Text(formattedTime(from: value))
                        .font(.system(size: 11))
                        .opacity(0.6)
                    Spacer()
                    Text(formattedTime(from: duration))
                        .font(.system(size: 11))
                        .opacity(0.6)
                }
            }
        }
    }
    
    private var duration: TimeInterval {
        range.upperBound - range.lowerBound
    }
    
    private func progressValue(at date: Date) -> TimeInterval {
        _ = date
        let playbackTime = isScrubbing ? currentTime : audioPlayer.currentTime
        return min(max(playbackTime - range.lowerBound, 0), duration)
    }
}

private struct TranscriptionTextView: View {
    var transcriptions: [AudioPlayer.Transcription]
    @State private var scrollPosition = ScrollPosition()
    var body: some View {
        ScrollView {
            HStack {
                VStack(alignment: .leading) {
                    ForEach(transcriptions) { transcription in
                        Text(transcription.attributedString)
                            .font(.system(size: 20, weight: .semibold))
                        if let translation = transcription.translation {
                            Text(translation)
                                .font(.system(size: 14))
                                .opacity(0.6)
                        }
                    }
                    Spacer()
                    .frame(height: 450)
                }
                Spacer(minLength: 10)
            }
            .padding()
            .padding(.top, 25)
        }
        .scrollPosition($scrollPosition)
        .onChange(of: transcriptions) {
            withAnimation {
                scrollPosition.scrollTo(edge: .bottom)
            }
        }
    }
}

private func formattedTime(from seconds: Double) -> String {
    guard seconds.isFinite else {
        return "0:00"
    }
    
    let totalSeconds = max(0, Int(seconds))
    let minutes = totalSeconds / 60
    let remainingSeconds = totalSeconds % 60
    
    guard totalSeconds >= 60 * 60 else {
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    return String(format: "%d:%02d:%02d", hours, remainingMinutes, remainingSeconds)
}

struct CustomProgressView: View {
    var value: Double
    var total: Double = 1.0
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(height: 6)
                Rectangle()
                    .fill(.white)
                    .frame(width: max(value / total, 0) * geometry.size.width, height: 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .fill(Color.gray)
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .opacity(configuration.isPressed ? 0.4 : kViewMinimumRenderableOpacity)
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
        }
    }
}
