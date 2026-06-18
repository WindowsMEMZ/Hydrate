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
import AVFoundation
import DarockFoundation
import SDWebImageSwiftUI
@_spi(Advanced) import SwiftUIIntrospect

struct ContentView: View {
    @FocusState var isSearchKeyboardFocused: Bool
    @Environment(SceneDelegate.self) private var sceneDelegate
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("AccountToken") private var accountToken = ""
    @AppStorage("MainTabSelection") private var tabSelection = 1
    @State private var audioPlayer = AudioPlayer.shared
    @State private var nowPlayingSheetPosition = BottomSheetPosition.hidden
    @State private var isAccountManagementPresented = false
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
            .padding(.top, (sceneDelegate.windowScene?.keyWindow?.safeAreaInsets.top ?? 0) - 5)
            .environment(\.colorScheme, .dark)
        } mainContent: {
            NowPlayingView()
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
        .showDragIndicator(false)
        .enableSwipeToDismiss()
        .enableFloatingIPadSheet(false)
        .sheetWidth(.absolute(sceneDelegate.keyWindowBounds.width))
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
                colors: audioPlayer.artworkBackgroundColors,
                background: .init(uiColor: .darkGray),
                smoothsColors: true
            )
            .blur(radius: 10, opaque: true)
            .overlay {
                Color.black.opacity(0.5)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: true ? (UIScreen.main.value(forKey: "_displayCornerRadius") as! Double) : 0
                )
            )
            .padding(-2)
        }
        .customThreshold(0.1)
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $isAccountManagementPresented, content: { AccountView() })
    }
    
    var nowPlayingView: some View {
        HStack {
            if let nowPlayingWork = audioPlayer.media?.sourceWork {
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
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play()
                    }
                }, label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
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
