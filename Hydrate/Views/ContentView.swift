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
        .sheet(isPresented: $isNowPlayingPresented) {
            NowPlayingView()
        }
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
            isNowPlayingPresented = true
        }
    }
}
