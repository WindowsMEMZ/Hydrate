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
import MediaPlayer
import AVFoundation
import NaturalLanguage
import DarockFoundation
@_spi(Advanced) import SwiftUIIntrospect

struct NowPlayingView: View {
    @Namespace private var coverScaleNamespace
    @Environment(SceneDelegate.self) private var sceneDelegate
    @State private var audioPlayer = AudioPlayer.shared
    @State private var currentPlaybackTime = 0.0
    @State private var currentScrolledId = 0.0
    @State private var visibleLyricIDs: Set<Double> = []
    @State private var isShowingControls = false
    @State private var isProgressDraging = false
    @State private var progressDragingNewTime = 0.0
    @State private var controlMenuDismissTimer: Timer?
    @State private var isUserScrolling = false
    @State private var canResetUserScrolling = false
    @State private var isScrollAnimationSet = false
    @State private var lyricScrollProxy: ScrollViewProxy?
    @State private var isVolumeDraging = false
    @State private var volumeView = MPVolumeView()
    @State private var volumeDragingNewValue = Double(AVAudioSession.sharedInstance().outputVolume)
    @State private var currentVolume = AVAudioSession.sharedInstance().outputVolume
    @State private var volumeObserver: NSKeyValueObservation?
    var body: some View {
        VStack {
            if let media = audioPlayer.media {
                ZStack {
                    if let lyrics = media.lyrics, !lyrics.isEmpty {
                        LyricsView(lyrics: lyrics, currentTime: currentPlaybackTime)
                    } else if let transcriptions = audioPlayer.transcriptions {
                        if let lyrics = transcriptions.asLyrics() {
                            LyricsView(lyrics: lyrics, currentTime: currentPlaybackTime)
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
                        .allowsHitTesting(false)
                        VStack {
                            Spacer()
                            VStack {
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
                                        Text(formattedTime(from: currentPlaybackTime))
                                            .font(.system(size: 11, weight: .semibold))
                                            .opacity(0.6)
                                        Spacer()
                                        Text(formattedTime(from: currentItemTotalTime))
                                            .font(.system(size: 11, weight: .semibold))
                                            .opacity(0.6)
                                    }
                                    .padding(.top, -14)
                                }
                                .scaleEffect(isProgressDraging ? 1.05 : 1)
                                .padding(.horizontal, 30)
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
                                            .font(.system(size: 50))
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
                                .padding(.bottom, 30)
                                HStack {
                                    Image(systemName: "speaker.fill")
                                        .font(.system(size: 14))
                                    ZStack {
                                        GenericUIViewRepresentable(view: volumeView)
                                            .offset(x: 1000, y: 1000)
                                            .frame(width: 10, height: 10)
                                        Slider(value: $volumeDragingNewValue) { isEditing in
                                            isVolumeDraging = isEditing
                                            if !isEditing {
                                                let slider = volumeView.subviews.first(where: { $0 is UISlider }) as! UISlider
                                                slider.value = Float(volumeDragingNewValue)
                                            }
                                        }
                                    }
                                    .sliderThumbVisibility(.hidden)
                                    .tint(.white)
                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.system(size: 14))
                                }
                                .scaleEffect(isVolumeDraging ? 1.05 : 1)
                                .padding(.horizontal, 40)
                                .animation(.easeOut(duration: 0.2), value: isVolumeDraging)
                                HStack {
                                    Spacer()
                                    GenericUIViewRepresentable(view: {
                                        let view = AVRoutePickerView()
                                        view.tintColor = UIColor(white: 1, alpha: 0.6)
                                        view.activeTintColor = UIColor(white: 1, alpha: 0.6)
                                        return view
                                    }())
                                    .frame(width: 50, height: 50)
                                    Spacer()
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                    .opacity(isShowingControls || alwaysShowControls ? 1.0 : 0.0)
                    .offset(y: isShowingControls || alwaysShowControls ? 0 : 10)
                    .animation(.easeOut(duration: 0.2), value: isShowingControls)
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
            isShowingControls = true
            resetMenuDismissTimer()
            UIApplication.shared.isIdleTimerDisabled = true
            volumeObserver = AVAudioSession.sharedInstance().observe(\.outputVolume, options: .new) { _, observedValue in
                if let newValue = observedValue.newValue {
                    currentVolume = newValue
                    if !isVolumeDraging {
                        volumeDragingNewValue = Double(newValue)
                    }
                }
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .environment(\.colorScheme, .dark)
        .onReceive(audioPlayer._player.periodicTimePublisher()) { time in
            // Code in this closure runs at nearly each frame, optimizing for speed is important.
            if time.seconds - currentPlaybackTime >= 0.3 || time.seconds < currentPlaybackTime {
                currentPlaybackTime = time.seconds
                if _fastPath(!isProgressDraging) {
                    progressDragingNewTime = currentPlaybackTime
                }
            }
        }
    }
    
    var currentItemTotalTime: TimeInterval {
        audioPlayer.audioDuration ?? 0
    }
    var alwaysShowControls: Bool {
        audioPlayer.media?.lyrics == nil
        && audioPlayer.transcriptions?.asLyrics() == nil
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
        controlMenuDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            if !isProgressDraging && !isVolumeDraging {
                isShowingControls = false
            } else {
                resetMenuDismissTimer()
            }
        }
    }
}

private let _lyricLineSpacing: CGFloat = 26
private let _lyricTopPadding: CGFloat = 80
private struct LyricsView: View {
    var lyrics: [ClosedRange<Double>: String]
    var currentTime: Double
    @AppStorage("TranscriptionTranslationEnabled") private var transcriptionTranslationEnabled = false
    @State private var audioPlayer = AudioPlayer.shared
    @State private var currentIndex = 0
    @State private var lineHeights: [CGFloat] = []
    @State private var pageOffset: CGFloat = 0
    @State private var underlyingScrollView: UIScrollView?
    @State private var heightBeforeCurrent: CGFloat = 0
    @State private var showingFullContent = false
    @State private var canResetShowingFullContent = false
    @State private var isShowingWaitingProgress = false
    @State private var pressedIndex: Int?
    @State private var translations: [String?] = []
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
                                    currentIndex = index
                                    showingFullContent = false
                                    audioPlayer.seek(to: lyricKeys[index].lowerBound)
                                    audioPlayer.play()
                                    withAnimation(.easeOut) {
                                        pageOffset = 0
                                    }
                                }
                            if isShowingWaitingProgress && currentIndex == index {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: 34)
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
                pageOffset = newValue
            }
            .onScrollPhaseChange { _, newPhase in
                if newPhase == .interacting || newPhase == .decelerating {
                    showingFullContent = true
                    canResetShowingFullContent = false
                } else {
                    canResetShowingFullContent = true
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
                                lineHeights: $lineHeights,
                                showingFullContent: $showingFullContent,
                                canResetShowingFullContent: $canResetShowingFullContent,
                                updatePageOffset: { newOffset in
                                    underlyingScrollView?.contentOffset.y = heightBeforeCurrent - newOffset
                                    pageOffset = newOffset
                                }
                            )
                        }
                        
                        if currentIndex < lyrics.count - 1 {
                            let waitingRange = lyricKeys[currentIndex].upperBound...lyricKeys[currentIndex + 1].lowerBound
                            let waitingDuration = waitingRange.upperBound - waitingRange.lowerBound
                            let isShowing = waitingDuration > 5 && waitingRange.contains(currentTime)
                            WaitingProgressView(
                                value: currentTime - lyricKeys[currentIndex].upperBound,
                                duration: waitingDuration
                            )
                            .opacity(isShowing ? 1 : 0)
                            .offset(y: 90)
                            .animation(.smooth, value: isShowing)
                            .onChange(of: isShowing) {
                                isShowingWaitingProgress = isShowing
                            }
                        }
                    }
                }
                .padding(.horizontal, 30)
                .transformEffect(.init(translationX: 0, y: pageOffset))
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
                .onChange(of: currentTime) {
                    // Update current index
                    for (index, range) in lyricKeys.enumerated() {
                        if range.contains(currentTime) {
                            currentIndex = index
                            break
                        }
                    }
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
    
    private func updateScrollOffset() {
        guard !showingFullContent else { return }
        
        var heightBeforeCurrent: CGFloat = 0
        if currentIndex > 0 {
            heightBeforeCurrent = lineHeights[0..<currentIndex].reduce(into: 0) {
                $0 += $1 + 26
            }
        }
        heightBeforeCurrent += isShowingWaitingProgress ? 60 : 0
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
        @Binding var lineHeights: [CGFloat]
        @Binding var showingFullContent: Bool
        @Binding var canResetShowingFullContent: Bool
        var updatePageOffset: (CGFloat) -> Void
        @State private var offset: CGFloat = 0
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray)
                    .opacity(isPressed ? 0.4 : 0)
                    .padding(.horizontal, -10)
                    .padding(.vertical, -3)
            }
            .opacity(isCurrent ? 1 : 0.6)
            .blur(radius: showingFullContent || isCurrent ? 0 : max(CGFloat(abs(currentIndex - index)), 1))
            .scaleEffect(isPressed ? 0.9 : 1)
            .offset(y: offset)
            .opacity( // performance: lazy
                isVisible ? 1 : 0
            )
            .animation(.smooth, value: isShowingWaitingProgress)
            .animation(.easeOut(duration: 0.2), value: isPressed)
            .onChange(of: lineHeights) {
                updateOffset()
            }
            .onChange(of: currentIndex) {
                updateOffset(indexBecomingCurrent: currentIndex)
            }
            .onChange(of: isShowingWaitingProgress) {
                updateOffset(indexBecomingCurrent: currentIndex)
            }
            .onChange(of: showingFullContent) {
                if !showingFullContent {
                    updateOffset(indexBecomingCurrent: currentIndex)
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
        
        private func updateOffset(indexBecomingCurrent: Int? = nil) {
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
                    waitingProgressOffset = -(lineHeights[index] + _lyricLineSpacing)
                } else {
                    waitingProgressOffset = -max(lineHeights[currentIndex] - 40, 0)
                }
            }
            
            func _update() {
                offset = _lyricTopPadding + heightBefore + CGFloat(index) * _lyricLineSpacing - heightBeforeCurrent + waitingProgressOffset
            }
            
            if let indexBecomingCurrent {
                if index == indexBecomingCurrent
                    && canResetShowingFullContent
                    && isVisible {
                    canResetShowingFullContent = false
                    showingFullContent = false
                    return // Actual update in next call, by onChange(of: showingFullContent)
                }
                if !showingFullContent {
                    withAnimation(.easeOut) {
                        updatePageOffset(0)
                    }
                    
                    if isVisible {
                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.1 * max(Double(index - indexBecomingCurrent), 0)
                        ) {
                            withAnimation(.spring) {
                                _update()
                            }
                        }
                    } else {
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
    var value: Double
    var duration: Double
    var body: some View {
        VStack {
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

@_effects(readnone)
private func formattedTime(from seconds: Double) -> String {
    if seconds.isNaN {
        return "00:00"
    }
    let minutes = Int(seconds) / 60
    let remainingSeconds = Int(seconds) % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

struct CustomProgressView: View {
    var value: Double
    var total: Double = 1.0
    var animationDuration: Double = 0.3
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
            .animation(.linear(duration: animationDuration), value: value)
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
