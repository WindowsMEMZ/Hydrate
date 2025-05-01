//
//  WorkDetailView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import SwiftUI
import DarockUI
import NotifKit
import Alamofire
import CachedAsyncImage
import DarockFoundation
@_spi(Advanced) import SwiftUIIntrospect

struct WorkDetailView: View {
    var id: Int
    @Namespace var ralatedWorkNavigationNamespace
    @AppStorage("AccountToken") var accountToken = ""
    @State var work: Work?
    @State var tracks: [TrackStructure]?
    @State var trackListHeightObservation: NSKeyValueObservation?
    @State var trackListHeight: CGFloat = 1
    @State var textFileURLPresentation: String?
    @State var textFilePresentationContent: String?
    @State var imageFileURLPresentation: String?
    @State var workTitleHeight: CGFloat = 0
    @State var scrollObservation: NSKeyValueObservation?
    @State var isShowingNavigationTitle = false
    @State var relatedWorks = [Work]()
    var body: some View {
        ScrollView {
            if let work {
                VStack {
                    CachedAsyncImage(url: URL(string: work.mainCoverUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray)
                            .redacted(reason: .placeholder)
                    }
                    .scaledToFill()
                    .frame(width: 220, height: 220)
                    .clipped()
                    .cornerRadius(8)
                    .shadow(radius: 15, x: 3, y: 3)
                    Text(work.title)
                        .font(.system(size: 16, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .background {
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        workTitleHeight = geometry.size.height
                                    }
                            }
                        }
                        .padding([.top, .horizontal])
                    Group {
                        if work.vas.count == 1 {
                            Button(action: {
                                performSearchSubject.send("$va:\(work.vas[0].name)$")
                            }, label: {
                                Text(work.vas[0].name)
                                    .font(.system(size: 16))
                            })
                        } else if work.vas.count > 1 {
                            Menu(work.vas.map { $0.name }.joined(separator: "/")) {
                                ForEach(work.vas, id: \.self) { va in
                                    Button(action: {
                                        performSearchSubject.send("$va:\(va.name)$")
                                    }, label: {
                                        Label(va.name, systemImage: "magnifyingglass")
                                    })
                                }
                            }
                            .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 5)
                    Menu {
                        ForEach(work.tags, id: \.self) { tag in
                            Button(action: {
                                performSearchSubject.send("$tag:\(tag.name)$")
                            }, label: {
                                Label(tag.name, systemImage: "magnifyingglass")
                            })
                        }
                    } label: {
                        Text(work.tags.map(\.name).joined(separator: " · "))
                            .font(.system(size: 11, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.gray)
                    }
                    .padding([.bottom, .horizontal])
                    if let tracks {
                        List(tracks, id: \.self, children: \.children) { track in
                            switch track.type {
                            case .folder:
                                Label(track.title, systemImage: "folder")
                            case .audio:
                                Button(action: {
                                    Task {
                                        var lyrics: [ClosedRange<Double>: String]?
                                        let allFiles = tracks.flattened
                                        for file in allFiles {
                                            if file.title == "\(track.title).vtt" || file.title == "\(track.title.dropLast(4)).vtt" {
                                                let result = await requestString(file.mediaStreamUrl!)
                                                if case let .success(respStr) = result {
                                                    lyrics = parseVTT(respStr)
                                                }
                                                break
                                            } else if file.title == "\(track.title).lrc" || file.title == "\(track.title.dropLast(4)).lrc" {
                                                let result = await requestString(file.mediaStreamUrl!)
                                                if case let .success(respStr) = result {
                                                    lyrics = parseLRC(respStr)
                                                }
                                                break
                                            }
                                        }
                                        nowPlayingMedia.send(.init(sourceWork: work, sourceTracks: tracks, playURL: track.mediaStreamUrl!, playFileName: String(track.title.dropLast(4)), lyrics: lyrics))
                                    }
                                }, label: {
                                    Label(track.title, systemImage: "music.quarternote.3")
                                })
                            case .text:
                                Button(action: {
                                    textFileURLPresentation = track.mediaStreamUrl!
                                }, label: {
                                    Label(track.title, systemImage: "text.document")
                                })
                            case .image:
                                Button(action: {
                                    imageFileURLPresentation = track.mediaStreamUrl!
                                }, label: {
                                    Label(track.title, systemImage: "photo")
                                })
                            case .other:
                                if let url = track.mediaStreamUrl {
                                    Link(destination: URL(string: url)!) {
                                        Label(track.title, systemImage: "document")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollDisabled(true)
                        .frame(height: trackListHeight)
                        .animation(.easeOut(duration: 0.2), value: trackListHeight)
                        .introspect(.list, on: .iOS(.v18...)) { tableView in
                            trackListHeightObservation = tableView.observe(\.contentSize) { _, _ in
                                trackListHeight = tableView.contentSize.height
                            }
                        }
                    } else {
                        ProgressView()
                    }
                    HStack {
                        VStack(alignment: .leading) {
                            Text(work.release)
                            Text({
                                let hours = work.duration / 3600
                                let minutes = (work.duration % 3600) / 60
                                let seconds = work.duration % 60
                                var components: [LocalizedStringResource] = []
                                if hours > 0 {
                                    components.append("\(hours)小时")
                                }
                                if minutes > 0 {
                                    components.append("\(minutes)分")
                                }
                                if seconds > 0 || components.isEmpty {
                                    components.append("\(seconds)秒")
                                }
                                return components.map{ String(localized: $0) }.joined()
                            }())
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                        Spacer()
                    }
                    .padding(.vertical)
                    if !relatedWorks.isEmpty {
                        VStack(alignment: .leading) {
                            Text("你可能还喜欢")
                                .font(.system(size: 22, weight: .bold))
                                .padding(.horizontal)
                            ScrollView(.horizontal) {
                                HStack(spacing: 0) {
                                    ForEach(relatedWorks) { work in
                                        NavigationLink {
                                            WorkDetailView(id: work.id)
                                                .navigationTransition(.zoom(sourceID: work.id, in: ralatedWorkNavigationNamespace))
                                        } label: {
                                            VStack(alignment: .leading) {
                                                CachedAsyncImage(url: URL(string: work.mainCoverUrl)) { image in
                                                    image.resizable()
                                                } placeholder: {
                                                    Rectangle()
                                                        .fill(Color.gray)
                                                        .redacted(reason: .placeholder)
                                                }
                                                .scaledToFill()
                                                .frame(width: 150, height: 150)
                                                .clipped()
                                                .cornerRadius(7)
                                                .matchedTransitionSource(id: work.id, in: ralatedWorkNavigationNamespace)
                                                Text(work.title)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .lineLimit(1)
                                                    .foregroundStyle(Color.primary)
                                                Text(work.vas.map { $0.name }.joined(separator: "/"))
                                                    .font(.system(size: 12))
                                                    .lineLimit(1)
                                                    .foregroundStyle(.gray)
                                            }
                                            .frame(width: 160)
                                        }
                                        .contextMenu {
                                            work.contextActions
                                        } preview: {
                                            work.previewView
                                        }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollIndicators(.never)
                            .scrollTargetBehavior(.viewAligned)
                        }
                        .padding(.vertical)
                        .background(Color(UIColor.secondarySystemBackground))
                        .padding(.horizontal, -16)
                    }
                }
                .padding()
                .padding(.bottom, 60)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .introspect(.scrollView, on: .iOS(.v18...)) { scrollView in
            scrollObservation = scrollView.observe(\.contentOffset, options: .new) { _, value in
                let scrollOffset = value.newValue ?? .init()
                isShowingNavigationTitle = scrollOffset.y - workTitleHeight > 170
            }
        }
        .navigationTitle(isShowingNavigationTitle ? (work?.title ?? "") : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let work {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        work.contextActions
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(5)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
            }
        }
        .sheet(item: $textFileURLPresentation) { url in
            NavigationStack {
                Group {
                    if let text = textFilePresentationContent {
                        TextEditor(text: .constant(text))
                            .padding()
                    } else {
                        ProgressView()
                            .controlSize(.large)
                    }
                }
                .navigationTitle("文本")
                .navigationBarTitleDisplayMode(.inline)
                .withDismissButton {
                    textFileURLPresentation = nil
                }
            }
            .task {
                let result = await requestString(url)
                if case let .success(respStr) = result {
                    textFilePresentationContent = respStr
                }
            }
            .onDisappear {
                textFilePresentationContent = nil
            }
        }
        .sheet(item: $imageFileURLPresentation) { url in
            NavigationStack {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                        .controlSize(.large)
                }
                .scaledToFit()
                .navigationTitle("图像")
                .navigationBarTitleDisplayMode(.inline)
                .withDismissButton({
                    textFileURLPresentation = nil
                }, placement: .leading)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            DispatchQueue(label: "com.memz233.Hydrate.SaveImageToPhotos", qos: .userInitiated).async {
                                if let _data = try? Data(contentsOf: URL(string: url)!),
                                   let image = UIImage(data: _data) {
                                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                                    NKTipper.automaticStyle.present(text: "已存储", symbol: "checkmark.circle.fill")
                                }
                            }
                        }, label: {
                            Image(systemName: "square.and.arrow.down")
                        })
                    }
                }
            }
        }
        .onAppear {
            loadWorkInfo()
            loadTrackInfo()
        }
    }
    
    func loadWorkInfo() {
        requestString("https://api.asmr.one/api/work/\(id)", headers: globalRequestHeaders) { respStr, isSuccess in
            if isSuccess {
                work = getJsonData(Work.self, from: respStr) ?? nil
                if let work {
                    requestJSON("https://api.asmr.one/api/recommender/item-neighbors", method: .post, parameters: ["keyword": "", "itemId": String(work.id), "localSubtitledWorks": [], "withPlaylistStatus": []], encoding: JSONEncoding.default, headers: globalRequestHeaders) { respJson, isSuccess in
                        if isSuccess {
                            relatedWorks = getJsonData([Work].self, from: respJson["works"].rawString()!) ?? []
                        }
                    }
                }
            }
        }
    }
    func loadTrackInfo() {
        requestString("https://api.asmr.one/api/tracks/\(id)?v=1", headers: globalRequestHeaders) { respStr, isSuccess in
            if isSuccess {
                tracks = getJsonData([TrackStructure].self, from: respStr) ?? nil
            }
        }
    }
}
