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
import DarockFoundation
@_spi(Advanced) import SwiftUIIntrospect

let globalAudioPlayer = AVPlayer()
var nowPlayingMedia = CurrentValueSubject<NowPlayingInfo?, Never>(nil)

struct NowPlayingView: View {
    @Namespace var coverScaleNamespace
    @State var nowPlaying: NowPlayingInfo?
    @State var currentPlaybackTime = globalAudioPlayer.currentTime().seconds
    @State var currentItemTotalTime = 0.0
    @State var currentScrolledId = 0.0
    @State var isShowingControls = false
    @State var isPlaying = false
    @State var isProgressDraging = false
    @State var progressDragingNewTime = 0.0
    @State var controlMenuDismissTimer: Timer?
    @State var isUserScrolling = false
    @State var canResetUserScrolling = false
    @State var isScrollAnimationSet = false
    @State var lyricScrollProxy: ScrollViewProxy?
    @State var isVolumeDraging = false
    @State var volumeView = MPVolumeView()
    @State var volumeDragingNewValue = Double(AVAudioSession.sharedInstance().outputVolume)
    @State var currentVolume = AVAudioSession.sharedInstance().outputVolume
    @State var volumeObserver: NSKeyValueObservation?
    var body: some View {
        VStack {
            if let nowPlaying {
                ZStack {
                    if let lyrics = nowPlaying.lyrics, !lyrics.isEmpty {
                        ScrollViewReader { scrollProxy in
                            let lyricKeys = Array<ClosedRange<Double>>(lyrics.keys).sorted(by: { lhs, rhs in lhs.lowerBound < rhs.lowerBound })
                            let lyricKeyAllBounds = lyricKeys.allBounds
                            ScrollView {
                                VStack(alignment: .leading, spacing: 20) {
                                    Spacer()
                                        .frame(height: 20)
                                    if let firstKey = lyricKeys.first {
                                        if firstKey.lowerBound >= 2.0 {
                                            WaitingDotsView(startTime: 0.0, endTime: firstKey.lowerBound, currentTime: $currentPlaybackTime)
                                        }
                                    }
                                    ForEach(0..<lyricKeys.count, id: \.self) { i in
                                        HStack {
                                            Text(lyrics[lyricKeys[i]]!)
                                                .font(.system(size: 30, weight: .bold))
                                                .fixedSize(horizontal: false, vertical: true)
                                            Spacer()
                                        }
                                        .opacity(currentScrolledId == lyricKeys[i].lowerBound ? 1.0 : 0.6)
                                        .blur(radius: currentScrolledId == lyricKeys[i].lowerBound || isUserScrolling ? 0 : abs(Double((lyricKeys.firstIndex { $0.lowerBound == currentScrolledId || $0.upperBound == currentScrolledId } ?? 0) - i)) * 3)
                                        .padding(.vertical, 5)
                                        .animation(.smooth, value: currentScrolledId)
                                        .modifier(LyricButtonModifier {
                                            globalAudioPlayer.seek(to: CMTime(seconds: lyricKeys[i].lowerBound, preferredTimescale: 60000),
                                                                   toleranceBefore: .zero,
                                                                   toleranceAfter: .zero)
                                            globalAudioPlayer.play()
                                            currentScrolledId = lyricKeys[i].lowerBound
                                            withAnimation {
                                                lyricScrollProxy?.scrollTo(lyricKeys[i].lowerBound, anchor: .init(x: 0.5, y: 0.13))
                                            }
                                        })
                                        .allowsHitTesting(isUserScrolling)
                                        .id(lyricKeys[i].lowerBound)
                                        if i < lyricKeys.count - 1 && lyricKeys[i &+ 1].lowerBound - lyricKeys[i].upperBound >= 5 {
                                            HStack {
                                                WaitingProgressView(startTime: lyricKeys[i].upperBound, endTime: lyricKeys[i &+ 1].lowerBound, currentTime: $currentPlaybackTime)
                                                Spacer()
                                            }
                                            .id(lyricKeys[i].upperBound)
                                        }
                                    }
                                    .scrollTransition { content, phase in
                                        content
                                            .scaleEffect(phase.isIdentity ? 1 : 0.98)
                                            .opacity(phase.isIdentity ? 1 : 0.5)
                                            .offset(y: phase == .bottomTrailing ? 10 : 0)
                                    }
                                    Spacer()
                                        .frame(height: 200)
                                }
                                .padding(.horizontal, 30)
                                .padding(.vertical)
                            }
                            .introspect(.scrollView, on: .iOS(.v18...)) { scrollView in
                                guard !isScrollAnimationSet else { return }
                                let animation = CASpringAnimation()
                                animation.mass = 1
                                animation.stiffness = 650
                                animation.damping = 300
                                animation.initialVelocity = 0
                                animation.duration = animation.settlingDuration
                                scrollView.setValue(animation, forKeyPath: "_animation._customAnimation")
                                scrollView.setValue(animation.settlingDuration, forKey: "_contentOffsetAnimationDuration")
                                isScrollAnimationSet = true
                            }
                            .onScrollPhaseChange { oldPhase, newPhase in
                                if newPhase == .interacting || newPhase == .decelerating {
                                    isUserScrolling = true
                                } else {
                                    canResetUserScrolling = true
                                }
                            }
                            .onAppear {
                                lyricScrollProxy = scrollProxy
                            }
                            .onReceive(globalAudioPlayer.periodicTimePublisher()) { _ in
                                var newScrollId = 0.0
                                var isUpdatedScrollId = false
                                for i in 0..<lyricKeyAllBounds.count where currentPlaybackTime < lyricKeyAllBounds[i] {
                                    if let newKey = lyricKeyAllBounds[from: i - 1] {
                                        newScrollId = newKey
                                    } else {
                                        newScrollId = lyricKeyAllBounds[i]
                                    }
                                    isUpdatedScrollId = true
                                    break
                                }
                                if _slowPath(!isUpdatedScrollId && !lyricKeys.isEmpty) {
                                    newScrollId = lyricKeys.last!.lowerBound
                                }
                                if _slowPath(newScrollId != currentScrolledId) {
                                    if canResetUserScrolling {
                                        canResetUserScrolling = false
                                        isUserScrolling = false
                                    }
                                    if !isUserScrolling {
                                        currentScrolledId = newScrollId
                                        withAnimation {
                                            scrollProxy.scrollTo(newScrollId, anchor: .init(x: 0.5, y: 0.13))
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        Text("文本不可用")
                    }
                    // Audio Controls
                    VStack {
                        Spacer()
                        VStack {
                            VStack {
                                Slider(value: $progressDragingNewTime, in: 0...currentItemTotalTime) { isEditing in
                                    isProgressDraging = isEditing
                                    if !isEditing {
                                        globalAudioPlayer.seek(to: .init(seconds: progressDragingNewTime, preferredTimescale: 60000))
                                        currentPlaybackTime = progressDragingNewTime
                                        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                                        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentPlaybackTime
                                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
                                    globalAudioPlayer.seek(
                                        to: CMTime(seconds: globalAudioPlayer.currentTime().seconds - 10, preferredTimescale: 60000),
                                        toleranceBefore: .zero,
                                        toleranceAfter: .zero)
                                    var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                                    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = globalAudioPlayer.currentTime().seconds - 10
                                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                                    resetMenuDismissTimer()
                                }, label: {
                                    Image(systemName: "10.arrow.trianglehead.counterclockwise")
                                        .font(.system(size: 30))
                                })
                                .buttonStyle(ControlButtonStyle())
                                .frame(width: 50, height: 50)
                                Button(action: {
                                    if isPlaying {
                                        globalAudioPlayer.pause()
                                    } else {
                                        globalAudioPlayer.play()
                                    }
                                    resetMenuDismissTimer()
                                }, label: {
                                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 50))
                                })
                                .buttonStyle(ControlButtonStyle())
                                .frame(width: 75, height: 75)
                                .padding(.horizontal, 40)
                                Button(action: {
                                    globalAudioPlayer.seek(
                                        to: CMTime(seconds: globalAudioPlayer.currentTime().seconds + 10, preferredTimescale: 60000),
                                        toleranceBefore: .zero,
                                        toleranceAfter: .zero)
                                    var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                                    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = globalAudioPlayer.currentTime().seconds + 10
                                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
                        .background {
                            Color(UIColor.darkGray)
                                .opacity(0.8)
                                .frame(width: UIScreen.main.bounds.width + 100, height: 400)
                                .blur(radius: 10)
                                .offset(y: 20)
                        }
                        .opacity(isShowingControls || nowPlaying.lyrics == nil ? 1.0 : 0.0)
                        .offset(y: isShowingControls || nowPlaying.lyrics == nil ? 0 : 10)
                        .animation(.easeOut(duration: 0.2), value: isShowingControls)
                    }
                    .ignoresSafeArea()
                }
                .navigationTitle(nowPlaying.sourceWork.title)
                .onTapGesture { location in
                    if location.y > UIScreen.main.bounds.height / 2 {
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
            nowPlaying = nowPlayingMedia.value
            isPlaying = globalAudioPlayer.timeControlStatus == .playing
            currentItemTotalTime = globalAudioPlayer.currentItem?.duration.seconds ?? 0.0
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
        .onReceive(nowPlayingMedia) { value in
            nowPlaying = value
        }
        .onReceive(globalAudioPlayer.publisher(for: \.timeControlStatus)) { status in
            isPlaying = status == .playing
            if status != .waitingToPlayAtSpecifiedRate {
                currentItemTotalTime = globalAudioPlayer.currentItem?.duration.seconds ?? 0.0
                debugPrint(currentItemTotalTime)
            }
        }
        .onReceive(globalAudioPlayer.publisher(for: \.currentItem)) { item in
            if let item {
                currentItemTotalTime = item.duration.seconds
            }
        }
        .onReceive(globalAudioPlayer.periodicTimePublisher()) { time in
            // Code in this closure runs at nearly each frame, optimizing for speed is important.
            if time.seconds - currentPlaybackTime >= 0.3 || time.seconds < currentPlaybackTime {
                currentPlaybackTime = time.seconds
                if _fastPath(!isProgressDraging) {
                    progressDragingNewTime = currentPlaybackTime
                }
            }
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
    struct WaitingProgressView: View {
        var startTime: Double
        var endTime: Double
        @Binding var currentTime: Double
        @State var isVisible = false
        @State var verticalPadding: CGFloat = -15
        var body: some View {
            VStack {
                CustomProgressView(value: (currentTime - startTime) / (endTime - startTime))
                    .frame(height: 15)
                HStack {
                    Text(formattedTime(from: currentTime - startTime))
                        .font(.system(size: 11))
                        .opacity(0.6)
                    Spacer()
                    Text(formattedTime(from: endTime - startTime))
                        .font(.system(size: 11))
                        .opacity(0.6)
                }
            }
            .padding(.vertical, verticalPadding)
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible ? 0 : 5)
            .scaleEffect(isVisible ? 1 : 0.6)
            .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: isVisible)
            .onChange(of: currentTime) {
                isVisible = currentTime >= startTime + 0.2 && currentTime <= endTime
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
    struct LyricButtonModifier: ViewModifier {
        var buttonAction: () -> Void
        @State private var isPressed = false
        func body(content: Content) -> some View {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray)
                    .scaleEffect(isPressed ? 0.9 : 1)
                    .opacity(isPressed ? 0.4 : 0)
                content
                    .scaleEffect(isPressed ? 0.9 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
            ._onButtonGesture(pressing: { isPressing in
                isPressed = isPressing
            }, perform: buttonAction)
            .onLongPressGesture(minimumDuration: 1.0) {
                
            }
            .animation(.easeOut(duration: 0.2), value: isPressed)
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
                    .frame(width: value / total * geometry.size.width, height: 6)
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
