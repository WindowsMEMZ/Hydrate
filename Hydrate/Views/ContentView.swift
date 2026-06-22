//
//  ContentView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import SwiftUI
import DarockUI
import Alamofire
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
    @State private var isNowPlayingPresented = false
    @State private var isAccountManagementPresented = false
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: .init { tabSelection } set: {
                if tabSelection == $0 && $0 == 3 {
                    isSearchKeyboardFocused = true
                }
                tabSelection = $0
            }) {
                Tab(value: 1) {
                    NavigationStack {
                        HomeView()
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button(action: {
                                        isAccountManagementPresented = true
                                    }, label: {
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 28, weight: .medium))
                                            .foregroundStyle(.accent)
                                    })
                                }
                                .sharedBackgroundVisibility(.hidden)
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
                                            .font(.system(size: 28, weight: .medium))
                                            .foregroundStyle(.accent)
                                    })
                                }
                                .sharedBackgroundVisibility(.hidden)
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
                                            .font(.system(size: 28, weight: .medium))
                                            .foregroundStyle(.accent)
                                    })
                                }
                                .sharedBackgroundVisibility(.hidden)
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
                                            .font(.system(size: 28, weight: .medium))
                                            .foregroundStyle(.accent)
                                    })
                                }
                                .sharedBackgroundVisibility(.hidden)
                            }
                    }
                }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory {
                nowPlayingAccessoryView
            }
            .onReceive(performSearchSubject) { text in
                if tabSelection != 3 {
                    tabSelection = 3
                    performSearchSubject.send(text)
                }
            }
        }
        .sheet(isPresented: $isNowPlayingPresented) {
            NowPlayingView()
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $isAccountManagementPresented, content: { AccountView() })
    }
    
    var nowPlayingAccessoryView: some View {
        HStack {
            if let media = audioPlayer.media {
                WebImage(url: URL(string: media.sourceWork.samCoverUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray)
                        .redacted(reason: .placeholder)
                }
                .scaledToFill()
                .frame(width: 35, height: 35)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 0) {
                    Text(media.sourceWork.title)
                        .font(.system(size: 13, weight: .semibold))
                        .marquee(trailingFade: 10)
                    Text(media.currentTrack.title)
                        .font(.system(size: 11))
                        .marquee(trailingFade: 10)
                }
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray)
                    .frame(width: 35, height: 35)
                    .redacted(reason: .placeholder)
                Text("未在播放")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
        }
        .frame(height: 53)
        .padding(.horizontal)
        .onTapGesture {
            isNowPlayingPresented = true
        }
    }
}
