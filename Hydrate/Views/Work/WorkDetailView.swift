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
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("AccountToken") private var accountToken = ""
    @AppStorage("RecentWorkPreservingCount") private var recentWorkPreservingCount = 10
    @State private var work: Work?
    @State private var tracks: [TrackStructure]?
    @State private var mainColor: (light: Color, dark: Color)?
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
                    .onSuccess { image, _, _ in
                        guard mainColor == nil else { return }
                        updateMainColor(from: image)
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
                            .foregroundStyle(Color.primary)
                            .opacity(0.7)
                    }
                    .padding([.bottom, .horizontal])
                    if let tracks {
                        TrackListView(tracks: tracks, work: work) { track in
                            trackTrailingArena(for: track)
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
                        .opacity(0.7)
                        Spacer()
                    }
                    .padding(.vertical)
                    if hasBottomInfoArea {
                        VStack(alignment: .leading, spacing: 30) {
                            ForEach(moreWorksByAuthor, id: \.0) { metadata in
                                VStack(alignment: .leading) {
                                    Text("更多\(metadata.0)的作品")
                                        .font(.system(size: 22, weight: .bold))
                                    WorkListView(works: metadata.1)
                                }
                            }
                            if !relatedWorks.isEmpty {
                                VStack(alignment: .leading) {
                                    Text("你可能也喜欢")
                                        .font(.system(size: 22, weight: .bold))
                                    WorkListView(works: relatedWorks)
                                }
                            }
                        }
                        .padding(.vertical)
                        .background {
                            Rectangle()
                                .fill(secondaryBackgroundColor)
                                .padding(.horizontal, -16)
                                .padding(.bottom, -500)
                        }
                    }
                }
                .padding()
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
        .containerBackground(backgroundColor, for: .navigation)
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
        .onAppear {
            trackDownloadProgressUpdate()
        }
        .onInitialAppear {
            loadWorkInfo()
        }
        .onDisappear {
            downloadProgressUpdateTimer?.invalidate()
        }
    }
    
    private var hasBottomInfoArea: Bool {
        !moreWorksByAuthor.isEmpty || !relatedWorks.isEmpty
    }
    
    private var backgroundColor: Color {
        (colorScheme == .dark ? mainColor?.dark : mainColor?.light)
            ?? Color(uiColor: .systemBackground)
    }
    private var secondaryBackgroundColor: Color {
        let resolved = backgroundColor.resolve(in: .init())
        var hue: CGFloat = 0,
            saturation: CGFloat = 0,
            brightness: CGFloat = 0
        UIColor(cgColor: resolved.cgColor).getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: nil
        )
        return Color(
            hue: hue,
            saturation: saturation,
            brightness: max(brightness - 0.05, 0)
        )
    }
    
    @ViewBuilder
    private func trackTrailingArena(for track: TrackStructure) -> some View {
        if let work, let tracks {
            HStack {
                if isTrackDownloaded(track) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 13))
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
    
    private func updateMainColor(from image: PlatformImage) {
        if let colors = ColorThief.getPalette(from: image, colorCount: 16),
           !colors.isEmpty {
            func compare(_ lhs: MMCQ.Color, rhs: MMCQ.Color) -> Bool {
                var brightness1: CGFloat = 0
                var brightness2: CGFloat = 0
                lhs.makePlatformNativeColor().getHue(
                    nil,
                    saturation: nil,
                    brightness: &brightness1,
                    alpha: nil
                )
                rhs.makePlatformNativeColor().getHue(
                    nil,
                    saturation: nil,
                    brightness: &brightness2,
                    alpha: nil
                )
                return brightness1 < brightness2
            }
            
            let lightColor = colors.max {
                compare($0, rhs: $1)
            }!.makePlatformNativeColor()
            let darkColor = colors.min {
                compare($0, rhs: $1)
            }!.makePlatformNativeColor()
            DispatchQueue.main.async {
                mainColor = (
                    Color(uiColor: lightColor),
                    Color(uiColor: darkColor)
                )
            }
        }
    }
    
    private func trackDownloadProgressUpdate() {
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
    
    private func loadWorkInfo() {
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
    private func updateDownloadedTracks() {
        if let downloadedBundle = DownloadManager.shared.bundleInfo(of: id) {
            downloadedTracks = Array(downloadedBundle.availableTracks.values)
        } else {
            downloadedTracks = []
        }
    }
    
    private func isTrackDownloaded(_ track: TrackStructure) -> Bool {
        downloadedTracks.contains(where: { $0.stableHashValue == track.stableHashValue })
    }
}
