//
//  WorkDetailView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import TipKit
import SwiftUI
import DarockUI
import NotifKit
import Alamofire
import DarockFoundation
import SDWebImageSwiftUI
@_spi(Advanced) import SwiftUIIntrospect

struct WorkDetailView: View {
    var id: Int
    @Namespace private var authorMoreWorkNavigationNamespace
    @Namespace private var ralatedWorkNavigationNamespace
    @AppStorage("AccountToken") private var accountToken = ""
    @AppStorage("RecentWorkPreservingCount") private var recentWorkPreservingCount = 10
    @State private var work: Work?
    @State private var tracks: [TrackStructure]?
    @State private var trackListHeightObservation: NSKeyValueObservation?
    @State private var trackListHeight: CGFloat = 1
    @State private var textFileURLPresentation: String?
    @State private var textFilePresentationContent: String?
    @State private var imageFileURLPresentation: String?
    @State private var workTitleHeight: CGFloat = 0
    @State private var isShowingNavigationTitle = false
    @State private var moreWorksByAuthor = [(String, [Work])]()
    @State private var relatedWorks = [Work]()
    @State private var downloadedTracks: [TrackStructure] = []
    @State private var downloadProgresses: [TrackStructure: Double] = [:]
    @State private var downloadProgressUpdateTimer: Timer?
    var body: some View {
        ScrollView {
            if let work {
                VStack {
                    WebImage(url: URL(string: work.mainCoverUrl)) { image in
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
                                        let lyrics = await parseLyrics(for: track, in: tracks, of: work)
                                        let playURL = DownloadManager.shared.contentURL(track: track, of: work)?.absoluteString ?? track.mediaStreamUrl!
                                        AudioPlayer.shared.media = .init(
                                            sourceWork: work,
                                            sourceTracks: tracks,
                                            currentTrack: track,
                                            playURL: playURL,
                                            playFileName: String(track.title.dropLast(4)),
                                            lyrics: lyrics
                                        )
                                    }
                                }, label: {
                                    HStack {
                                        Label(track.title, systemImage: "music.quarternote.3")
                                        Spacer()
                                        trackTrailingArena(for: track)
                                    }
                                })
                            case .text:
                                Button(action: {
                                    textFileURLPresentation = DownloadManager.shared.contentURL(track: track, of: work)?.absoluteString ?? track.mediaStreamUrl!
                                }, label: {
                                    HStack {
                                        Label(track.title, systemImage: "text.document")
                                        Spacer()
                                        trackTrailingArena(for: track)
                                    }
                                })
                            case .image:
                                Button(action: {
                                    imageFileURLPresentation = DownloadManager.shared.contentURL(track: track, of: work)?.absoluteString ?? track.mediaStreamUrl!
                                }, label: {
                                    HStack {
                                        Label(track.title, systemImage: "photo")
                                        Spacer()
                                        trackTrailingArena(for: track)
                                    }
                                })
                            case .other:
                                if let url = track.mediaStreamUrl {
                                    Link(destination: URL(string: url)!) {
                                        HStack {
                                            Label(track.title, systemImage: "document")
                                            Spacer()
                                            trackTrailingArena(for: track)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollDisabled(true)
                        .frame(height: trackListHeight)
                        .padding(.horizontal, -16)
                        .introspect(.list, on: .iOS(.v26...)) { tableView in
                            trackListHeightObservation = tableView.observe(\.contentSize) { _, _ in
                                trackListHeight = tableView.contentSize.height
                            }
                        }
                    } else {
                        ProgressView()
                    }
                    HStack {
                        VStack(alignment: .leading) {
                            Text(work.release.replacingOccurrences(of: "-", with: "/"))
                            if let tracks {
                                Text({
                                    let hours = work.duration / 3600
                                    let minutes = (work.duration % 3600) / 60
                                    var components: [LocalizedStringResource] = []
                                    if hours > 0 {
                                        components.append("\(hours)小时")
                                    }
                                    if minutes > 0 || components.isEmpty {
                                        components.append("\(minutes)分钟")
                                    }
                                    return String(localized: "\(tracks.flattened.filter { $0.type != .folder }.count)个项目，\(components.map{ String(localized: $0) }.joined())")
                                }())
                                Text({
                                    let sizes = tracks.flattened.compactMap(\.size)
                                    var byte: UInt64 = 0
                                    for size in sizes {
                                        byte += size
                                    }
                                    let formatter = ByteCountFormatter()
                                    return formatter.string(fromByteCount: Int64(byte))
                                }())
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                        Spacer()
                    }
                    .padding(.vertical)
                    if !relatedWorks.isEmpty {
                        VStack(alignment: .leading) {
                            if !moreWorksByAuthor.isEmpty {
                                ForEach(moreWorksByAuthor, id: \.0) { metadata in
                                    Text("更多\(metadata.0)的作品")
                                        .font(.system(size: 22, weight: .bold))
                                        .padding(.horizontal)
                                    ScrollView(.horizontal) {
                                        LazyHStack(spacing: 0) {
                                            ForEach(metadata.1) { work in
                                                NavigationLink {
                                                    WorkDetailView(id: work.id)
                                                        .navigationTransition(.zoom(sourceID: work.id, in: ralatedWorkNavigationNamespace))
                                                } label: {
                                                    VStack(alignment: .leading) {
                                                        WebImage(url: URL(string: work.mainCoverUrl)) { image in
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
                                        .scrollTransition { content, _ in
                                            content.offset(x: 14)
                                        }
                                    }
                                    .scrollIndicators(.never)
                                    .scrollTargetBehavior(.viewAligned)
                                }
                            }
                            Text("你可能也喜欢")
                                .font(.system(size: 22, weight: .bold))
                                .padding(.horizontal)
                            ScrollView(.horizontal) {
                                LazyHStack(spacing: 0) {
                                    ForEach(relatedWorks) { work in
                                        NavigationLink {
                                            WorkDetailView(id: work.id)
                                                .navigationTransition(.zoom(sourceID: work.id, in: ralatedWorkNavigationNamespace))
                                        } label: {
                                            VStack(alignment: .leading) {
                                                WebImage(url: URL(string: work.mainCoverUrl)) { image in
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
                                .scrollTransition { content, _ in
                                    content.offset(x: 14)
                                }
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
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y - workTitleHeight > 170
        } action: { _, newValue in
            isShowingNavigationTitle = newValue
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
                    .padding(.horizontal, -10)
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
            .onAppear {
                Task {
                    let result = await requestString(url)
                    if case let .success(respStr) = result {
                        textFilePresentationContent = respStr
                    }
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
        }
        .onDisappear {
            downloadProgressUpdateTimer?.invalidate()
        }
    }
    
    @ViewBuilder
    func trackTrailingArena(for track: TrackStructure) -> some View {
        if let work, let tracks {
            HStack {
                if isTrackDownloaded(track) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.secondary)
                } else if let progress = downloadProgresses[track] {
                    Gauge(value: progress, label: {})
                        .gaugeStyle(.accessoryCircularCapacity)
                        .tint(.accentColor)
                        .scaleEffect(0.3)
                        .frame(width: 20, height: 20)
                        .animation(.smooth, value: progress)
                        .popoverTip(TrackDownloadingTip(), arrowEdge: .top)
                }
                Menu {
                    if !isTrackDownloaded(track) {
                        Button("下载", systemImage: "arrow.down.circle") {
                            DownloadManager.shared.download(track: track, of: work, allTracks: tracks)
                        }
                    } else if let id = DownloadManager.shared.downloadingTracks.first(where: { $0.0 == track })?.1 {
                        Button("取消下载", systemImage: "xmark.circle") {
                            DownloadManager.shared.cancelTask(for: id)
                            updateDownloadedTracks()
                        }
                    } else {
                        Button("移除下载", systemImage: "xmark.circle") {
                            DownloadManager.shared.remove(track: track, of: work)
                            updateDownloadedTracks()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.secondary)
                        .padding(5)
                }
                .contentShape(Rectangle())
            }
        }
    }
    
    func trackDownloadProgressUpdate() {
        downloadProgressUpdateTimer?.invalidate()
        downloadProgressUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard let tracks = tracks?.flattened else { return }
            
            updateDownloadedTracks()
            
            let downloadingTracks = DownloadManager.shared.downloadingTracks
                .filter { tracks.contains($0.0) }
            downloadProgresses = downloadingTracks.reduce(into: [:]) { partialResult, _info in
                let (track, taskID) = _info
                if let progress = DownloadManager.shared.progress(for: taskID) {
                    partialResult.updateValue(progress, forKey: track)
                }
            }
        }
    }
    
    func loadWorkInfo() {
        Task {
            updateDownloadedTracks()
            if let downloadedBundle = DownloadManager.shared.bundleInfo(of: id) {
                work = downloadedBundle.work
                tracks = downloadedBundle.allTracks
            } else {
                requestString("https://api.asmr.one/api/tracks/\(id)?v=1", headers: globalRequestHeaders) { respStr, isSuccess in
                    if isSuccess {
                        tracks = getJsonData([TrackStructure].self, from: respStr) ?? nil
                    }
                }
                
                let result = await requestString("https://api.asmr.one/api/work/\(id)", headers: globalRequestHeaders)
                if case let .success(respStr) = result {
                    work = getJsonData(Work.self, from: respStr) ?? nil
                }
            }
            if let work {
                trackDownloadProgressUpdate()
                Task {
                    moreWorksByAuthor.removeAll()
                    for va in work.vas {
                        let result = await requestJSON("https://api.asmr.one/api/search/$va:\(va.name.urlEncoded())$?order=create_date&sort=desc&page=1&subtitle=0&includeTranslationWorks=true")
                        if case let .success(respJson) = result,
                           let works = getJsonData([Work].self, from: respJson["works"].rawString()!),
                           !works.isEmpty {
                            moreWorksByAuthor.append((va.name, works))
                        }
                    }
                }
                requestJSON("https://api.asmr.one/api/recommender/item-neighbors", method: .post, parameters: ["keyword": "", "itemId": String(work.id), "localSubtitledWorks": [], "withPlaylistStatus": []], encoding: JSONEncoding.default, headers: globalRequestHeaders) { respJson, isSuccess in
                    if isSuccess {
                        relatedWorks = getJsonData([Work].self, from: respJson["works"].rawString()!) ?? []
                    }
                }
                
                var recentWorks = [Work]()
                if let _recentData = try? Data(contentsOf: URL(filePath: NSHomeDirectory() + "/Documents/Recents.plist")),
                   let recents = try? PropertyListDecoder().decode([Work].self, from: _recentData) {
                    recentWorks = recents
                }
                if !recentWorks.contains(work) {
                    recentWorks.insert(work, at: 0)
                    if recentWorks.count > recentWorkPreservingCount {
                        recentWorks.removeLast(recentWorks.count - recentWorkPreservingCount)
                    }
                } else {
                    recentWorks.move(fromOffsets: [recentWorks.firstIndex(of: work)!], toOffset: 0)
                }
                let encoder = PropertyListEncoder()
                encoder.outputFormat = .binary
                if let recentData = try? encoder.encode(recentWorks) {
                    try? recentData.write(to: URL(filePath: NSHomeDirectory() + "/Documents/Recents.plist"))
                }
            }
        }
    }
    func updateDownloadedTracks() {
        if let downloadedBundle = DownloadManager.shared.bundleInfo(of: id) {
            downloadedTracks = Array(downloadedBundle.availableTracks.values)
        } else {
            downloadedTracks = []
        }
    }
    
    func isTrackDownloaded(_ track: TrackStructure) -> Bool {
        downloadedTracks.contains(where: { $0.stableHashValue == track.stableHashValue })
    }
}
