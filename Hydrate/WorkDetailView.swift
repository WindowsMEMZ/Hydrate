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
import DarockFoundation
import SDWebImageSwiftUI
@_spi(Advanced) import SwiftUIIntrospect

struct WorkDetailView: View {
    var id: Int
    @Namespace var authorMoreWorkNavigationNamespace
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
    @State var moreWorksByAuthor = [(String, [Work])]()
    @State var relatedWorks = [Work]()
    @State var isDownloaded = false
    @State var downloadProgress: Double?
    @State var individualDownloadProgresses: [TrackStructure: Double]?
    @State var downloadProgressUpdateTimer: Timer?
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
                                    HStack {
                                        Label(track.title, systemImage: "music.quarternote.3")
                                        if !isDownloaded,
                                           let _progress = downloadProgress,
                                           _progress < 1,
                                           let individualDownloadProgresses,
                                           let progress = individualDownloadProgresses[track] {
                                            Spacer()
                                            if progress < 1 {
                                                Gauge(value: progress, label: {})
                                                    .gaugeStyle(.accessoryCircularCapacity)
                                                    .tint(.accentColor)
                                                    .scaleEffect(0.3)
                                                    .frame(width: 20, height: 20)
                                                    .animation(.smooth, value: progress)
                                            } else {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(.gray)
                                            }
                                        }
                                    }
                                })
                            case .text:
                                Button(action: {
                                    textFileURLPresentation = track.mediaStreamUrl!
                                }, label: {
                                    HStack {
                                        Label(track.title, systemImage: "text.document")
                                        if !isDownloaded,
                                           let _progress = downloadProgress,
                                           _progress < 1,
                                           let individualDownloadProgresses,
                                           let progress = individualDownloadProgresses[track] {
                                            Spacer()
                                            if progress < 1 {
                                                Gauge(value: progress, label: {})
                                                    .gaugeStyle(.accessoryCircularCapacity)
                                                    .tint(.accentColor)
                                                    .scaleEffect(0.3)
                                                    .frame(width: 20, height: 20)
                                                    .animation(.smooth, value: progress)
                                            } else {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(.gray)
                                            }
                                        }
                                    }
                                })
                            case .image:
                                Button(action: {
                                    imageFileURLPresentation = track.mediaStreamUrl!
                                }, label: {
                                    HStack {
                                        Label(track.title, systemImage: "photo")
                                        if !isDownloaded,
                                           let _progress = downloadProgress,
                                           _progress < 1,
                                           let individualDownloadProgresses,
                                           let progress = individualDownloadProgresses[track] {
                                            Spacer()
                                            if progress < 1 {
                                                Gauge(value: progress, label: {})
                                                    .gaugeStyle(.accessoryCircularCapacity)
                                                    .tint(.accentColor)
                                                    .scaleEffect(0.3)
                                                    .frame(width: 20, height: 20)
                                                    .animation(.smooth, value: progress)
                                            } else {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(.gray)
                                            }
                                        }
                                    }
                                })
                            case .other:
                                if let url = track.mediaStreamUrl {
                                    Link(destination: URL(string: url)!) {
                                        HStack {
                                            Label(track.title, systemImage: "document")
                                            if !isDownloaded,
                                               let _progress = downloadProgress,
                                               _progress < 1,
                                               let individualDownloadProgresses,
                                               let progress = individualDownloadProgresses[track] {
                                                Spacer()
                                                if progress < 1 {
                                                    Gauge(value: progress, label: {})
                                                        .gaugeStyle(.accessoryCircularCapacity)
                                                        .tint(.accentColor)
                                                        .scaleEffect(0.3)
                                                        .frame(width: 20, height: 20)
                                                        .animation(.smooth, value: progress)
                                                } else {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 16))
                                                        .foregroundStyle(.gray)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollDisabled(true)
                        .frame(height: trackListHeight)
                        .padding(.horizontal, -16)
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
                    if let tracks {
                        if !isDownloaded {
                            Button(action: {
                                if downloadProgress == nil {
                                    try? DownloadManager.shared.createTask(for: work, withTracks: tracks)
                                    trackDownloadProgressUpdate()
                                } else {
                                    DownloadManager.shared.cancelTask(for: work.id)
                                }
                            }, label: {
                                if let downloadProgress {
                                    ZStack {
                                        Gauge(value: downloadProgress, label: {})
                                            .gaugeStyle(.accessoryCircularCapacity)
                                            .tint(.accentColor)
                                            .scaleEffect(0.5)
                                            .animation(.smooth, value: downloadProgress)
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 12))
                                    }
                                    .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 14, weight: .bold))
                                }
                            })
                        } else {
                            Menu {
                                Button("移除下载", systemImage: "trash", role: .destructive) {
                                    DownloadManager.shared.remove(id: work.id)
                                    isDownloaded = false
                                    downloadProgress = nil
                                    loadWorkInfo()
                                    loadTrackInfo()
                                }
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .menuStyle(.button)
                        }
                    }
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
        .onDisappear {
            downloadProgressUpdateTimer?.invalidate()
        }
    }
    
    func trackDownloadProgressUpdate() {
        downloadProgressUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            let newProgress = DownloadManager.shared.progress(for: id)
            if _slowPath(newProgress == 1 || (downloadProgress != nil && newProgress == nil)) {
                downloadProgressUpdateTimer?.invalidate()
                if newProgress == 1 {
                    isDownloaded = true
                    loadWorkInfo()
                    loadTrackInfo()
                }
            }
            downloadProgress = newProgress
            if let tracks {
                individualDownloadProgresses = DownloadManager.shared.individualProgress(for: id, withTracks: tracks)
            }
        }
    }
    
    func loadWorkInfo() {
        Task {
            isDownloaded = DownloadManager.shared.isDownloaded(for: id)
            if !isDownloaded {
                let result = await requestString("https://api.asmr.one/api/work/\(id)", headers: globalRequestHeaders)
                if case let .success(respStr) = result {
                    work = getJsonData(Work.self, from: respStr) ?? nil
                }
            } else {
                work = DownloadManager.shared.work(of: id)
            }
            if let work {
                downloadProgress = DownloadManager.shared.progress(for: work.id)
                if let progress = downloadProgress, progress < 1 {
                    trackDownloadProgressUpdate()
                }
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
                    if recentWorks.count > 10 {
                        recentWorks.removeLast()
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
    func loadTrackInfo() {
        isDownloaded = DownloadManager.shared.isDownloaded(for: id)
        if !isDownloaded {
            requestString("https://api.asmr.one/api/tracks/\(id)?v=1", headers: globalRequestHeaders) { respStr, isSuccess in
                if isSuccess {
                    tracks = getJsonData([TrackStructure].self, from: respStr) ?? nil
                }
            }
        } else {
            tracks = DownloadManager.shared.tracks(of: id)
        }
    }
}
