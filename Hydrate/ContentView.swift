//
//  ContentView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import SwiftUI
import DarockUI
import Alamofire
import BottomSheet
import MediaPlayer
import AVFoundation
import DarockFoundation
import SDWebImageSwiftUI
@_spi(Advanced) import SwiftUIIntrospect

struct ContentView: View {
    @FocusState var isSearchKeyboardFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("AccountToken") var accountToken = ""
    @AppStorage("MainTabSelection") var tabSelection = 1
    @State var nowPlayingSheetPosition = BottomSheetPosition.hidden
    @State var nowPlayingWork: Work?
    @State var nowPlayingBackgroundColors = Array(repeating: Color(uiColor: .darkGray), count: 16)
    @State var isAccountManagementPresented = false
    @State var isNowPlayingStarred = false
    @State var isNowPlaying = false
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tabSelection) {
                Tab(value: 1) {
                    NavigationStack {
                        HomeView()
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(action: {
                                        isAccountManagementPresented = true
                                    }, label: {
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.accent)
                                    })
                                }
                            }
                    }
                } label: {
                    Image(_internalSystemName: "home.fill")
                    Text("主页")
                }
                Tab("最近浏览", systemImage: "clock.fill", value: 4) {
                    NavigationStack {
                        RecentsView()
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(action: {
                                        isAccountManagementPresented = true
                                    }, label: {
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.accent)
                                    })
                                }
                            }
                    }
                }
                Tab("资料库", systemImage: "rectangle.stack.fill", value: 2) {
                    NavigationStack {
                        LibraryView()
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(action: {
                                        isAccountManagementPresented = true
                                    }, label: {
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.accent)
                                    })
                                }
                            }
                    }
                }
                Tab("搜索", systemImage: "magnifyingglass", value: 3, role: .search) {
                    NavigationStack {
                        SearchView(isSearchKeyboardFocused: $isSearchKeyboardFocused)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(action: {
                                        isAccountManagementPresented = true
                                    }, label: {
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(.accent)
                                    })
                                }
                            }
                    }
                }
            }
            .tabViewBottomAccessory {
                nowPlayingView
            }
            .onReceive(performSearchSubject) { text in
                if tabSelection != 3 {
                    tabSelection = 3
                    performSearchSubject.send(text)
                }
            }
        }
        .bottomSheet(bottomSheetPosition: $nowPlayingSheetPosition, switchablePositions: [.hidden, .relativeTop(1)]) {
            VStack {
                Capsule()
                    .fill(Color(UIColor.tertiaryLabel))
                    .frame(width: 36, height: 5)
                    .centerAligned()
                    .allowsHitTesting(false)
                HStack(spacing: 5) {
                    if let nowPlayingWork {
                        WebImage(url: URL(string: nowPlayingWork.mainCoverUrl)) { image in
                            image.resizable()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray)
                                .redacted(reason: .placeholder)
                        }
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipped()
                        .cornerRadius(6)
                        VStack(alignment: .leading, spacing: 3) {
                            MarqueeText(text: nowPlayingWork.title, font: .systemFont(ofSize: 14, weight: .semibold), leftFade: 4, rightFade: 4, startDelay: 4, alignment: .leading)
                            Menu(nowPlayingWork.vas.map { $0.name }.joined(separator: "/")) {
                                ForEach(nowPlayingWork.vas, id: \.self) { va in
                                    Button(action: {
                                        performSearchSubject.send("$va:\(va.name)$")
                                    }, label: {
                                        Label(va.name, systemImage: "magnifyingglass")
                                    })
                                }
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .opacity(0.6)
                        }
                        if !accountToken.isEmpty {
                            StarButton(isStarred: $isNowPlayingStarred) {
                                if !isNowPlayingStarred {
                                    requestJSON("https://api.asmr.one/api/review", method: .put, parameters: ["work_id": nowPlayingWork.id, "rating": 5, "review_text": nil, "progress": nil], encoding: JSONEncoding.default, headers: globalRequestHeaders) { _, _ in }
                                } else {
                                    requestJSON("https://api.asmr.one/api/review?work_id=\(nowPlayingWork.id)", method: .delete, headers: globalRequestHeaders) { _, _ in }
                                }
                                isNowPlayingStarred.toggle()
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
            .padding(.horizontal)
            .padding(.top, 45)
            .environment(\.colorScheme, .dark)
        } mainContent: {
            NowPlayingView()
                .mask {
                    LinearGradient(colors: [.black.opacity(0), .black, .black, .black, .black, .black, .black, .black], startPoint: .top, endPoint: .bottom)
                }
        }
        .showDragIndicator(false)
        .enableSwipeToDismiss()
        .enableFloatingIPadSheet(false)
        .sheetWidth(.absolute(UIScreen.main.bounds.width))
        .customAnimation(.spring(response: 0.4, dampingFraction: 1, blendDuration: 0.8))
        .customBackground {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
                    SIMD2<Float>(0.0, 0.5), SIMD2<Float>(0.45, 0.55), SIMD2<Float>(1.0, 0.5),
                    SIMD2<Float>(0.0, 1.0), SIMD2<Float>(0.5, 1.0), SIMD2<Float>(1.0, 1.0)
                ],
                colors: nowPlayingBackgroundColors,
                background: .init(uiColor: .darkGray),
                smoothsColors: true
            )
            .blur(radius: 10, opaque: true)
            .overlay {
                Color.black.opacity(0.6)
            }
            .clipShape(RoundedRectangle(cornerRadius: true ? (UIScreen.main.value(forKey: "_displayCornerRadius") as! Double) : 0))
            .padding(-2)
        }
        .customThreshold(0.1)
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $isAccountManagementPresented, content: { AccountView() })
        .onReceive(nowPlayingMedia) { media in
            if let media {
                globalAudioPlayer.replaceCurrentItem(with: AVPlayerItem(url: URL(string: media.playURL)!))
                if !media.preventAutoPlaying {
                    try? AVAudioSession.sharedInstance().setActive(true)
                    globalAudioPlayer.play()
                }
                nowPlayingWork = media.sourceWork
                isNowPlayingStarred = media.sourceWork.userRating != nil
                DispatchQueue(label: "com.memz233.Hydrate.UpdateNowPlayingInfo", qos: .utility).async {
                    var nowPlayingInfo = [String: Any]()
                    if let imageUrl = URL(string: media.sourceWork.mainCoverUrl),
                       let imageData = try? Data(contentsOf: imageUrl),
                       let image = UIImage(data: imageData) {
                        nowPlayingBackgroundColors = ColorThief.getPalette(from: image, colorCount: 16)!.map {
                            Color(red: Double($0.r) / 255, green: Double($0.g) / 255, blue: Double($0.b) / 255)
                        }
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    }
                    nowPlayingInfo[MPMediaItemPropertyTitle] = media.playFileName
                    nowPlayingInfo[MPMediaItemPropertyArtist] = media.sourceWork.vas.map { $0.name }.joined(separator: "/")
                    nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = media.sourceWork.title
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
                if let jsonData = jsonString(from: media) {
                    try? jsonData.write(toFile: NSHomeDirectory() + "/Documents/LatestNowPlaying.json", atomically: true, encoding: .utf8)
                }
            }
        }
        .onReceive(globalAudioPlayer.publisher(for: \.timeControlStatus)) { status in
            isNowPlaying = status == .playing
            if var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isNowPlaying ? 1.0 : 0.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
        }
        .onReceive(globalAudioPlayer.publisher(for: \.currentItem)) { item in
            if let item {
                Task {
                    var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = try? await item.asset.load(.duration).seconds
                    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
                    nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }
        }
    }
    
    var nowPlayingView: some View {
        HStack {
            if let nowPlayingWork {
                WebImage(url: URL(string: nowPlayingWork.samCoverUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray)
                        .redacted(reason: .placeholder)
                }
                .scaledToFill()
                .frame(width: 35, height: 35)
                .clipped()
                .cornerRadius(10)
                Text(nowPlayingWork.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button(action: {
                    if isNowPlaying {
                        globalAudioPlayer.pause()
                    } else {
                        globalAudioPlayer.play()
                    }
                }, label: {
                    Image(systemName: isNowPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                })
                .buttonStyle(ControlButtonStyle())
                .frame(width: 40, height: 40)
            } else {
                Text("未在播放")
                Spacer()
            }
        }
        .frame(height: 53)
        .padding(.horizontal)
        .onTapGesture {
            nowPlayingSheetPosition = .relativeTop(1)
        }
    }
}
