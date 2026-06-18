//
//  Models.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import SwiftUI
import NotifKit
import Alamofire
import DarockFoundation
import SDWebImageSwiftUI

struct Pagination: Decodable {
    var currentPage: Int
    var pageSize: Int
    var totalCount: Int
}

struct Work: Identifiable, Equatable, Codable {
    var id: Int
    var title: String
    var circle_id: Int
    var name: String
    var nsfw: Bool
    var release: String
    var dl_count: Int
    var price: Int
    var review_count: Int
    var rate_count: Int
    var rate_average_2dp: Double
    var rank: [Rank]?
    var has_subtitle: Bool
    var create_date: String
    var vas: [VA]
    var tags: [Tag]
    var original_workno: String?
    var other_language_editions_in_db: [LanguageEditionInDB]
    var translation_info: TranslationInfo
    var work_attributes: String
    var age_category_string: String
    var duration: Int
    var source_type: String
    var source_id: String
    var source_url: String
    var userRating: Int?
    var samCoverUrl: String
    var thumbnailCoverUrl: String
    var mainCoverUrl: String
    
    var previewView: some View {
        VStack(alignment: .leading) {
            WebImage(url: URL(string: self.mainCoverUrl)) { image in
                image.resizable()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray)
                    .redacted(reason: .placeholder)
            }
            .scaledToFill()
            .frame(width: UIScreen.main.bounds.width - 100, height: UIScreen.main.bounds.width - 100)
            .clipped()
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 5)
            Group {
                Text(self.title)
                    .font(.system(size: 16, weight: .semibold))
                Text(self.vas.map { $0.name }.joined(separator: "/"))
                    .foregroundStyle(.gray)
                Spacer()
                    .frame(height: 3)
                Text(self.tags.map(\.name).joined(separator: " · "))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal)
        }
        .frame(width: UIScreen.main.bounds.width - 70, height: UIScreen.main.bounds.width + 40)
    }
    @ViewBuilder
    var contextActions: some View {
        Section {
            if !(UserDefaults.standard.string(forKey: "AccountToken") ?? "").isEmpty {
                if self.userRating != nil {
                    Button("从收藏中移除", systemImage: "trash", role: .destructive) {
                        requestJSON("https://api.asmr.one/api/review?work_id=\(self.id)", method: .delete, headers: globalRequestHeaders) { _, isSuccess in
                            if !isSuccess {
                                NKTipper.automaticStyle.present(text: "移除时出错", symbol: "xmark.circle.fill")
                            }
                        }
                    }
                } else {
                    Button("收藏", systemImage: "star") {
                        requestJSON("https://api.asmr.one/api/review", method: .put, parameters: ["work_id": self.id, "rating": 5, "review_text": nil, "progress": nil], encoding: JSONEncoding.default, headers: globalRequestHeaders) { _, isSuccess in
                            if isSuccess {
                                NKTipper.automaticStyle.present(text: "已添加到收藏", symbol: "checkmark.circle.fill")
                            } else {
                                NKTipper.automaticStyle.present(text: "收藏时出错", symbol: "xmark.circle.fill")
                            }
                        }
                    }
                }
                if let progress = DownloadManager.shared.progress(for: id), progress < 1 {
                    Button(action: {
                        DownloadManager.shared.cancelTask(for: id)
                    }, label: {
                        Image(_internalSystemName: "stop.circle.open")
                        Text("停止下载")
                    })
                } else if !DownloadManager.shared.isDownloaded(for: id) {
                    Button("下载", systemImage: "arrow.down.circle") {
                        requestString("https://api.asmr.one/api/tracks/\(id)?v=1", headers: globalRequestHeaders) { respStr, isSuccess in
                            if isSuccess, let tracks = getJsonData([TrackStructure].self, from: respStr) {
                                try? DownloadManager.shared.createTask(for: self, withTracks: tracks)
                            }
                        }
                    }
                } else {
                    Button("移除下载", systemImage: "trash", role: .destructive) {
                        DownloadManager.shared.remove(id: id)
                    }
                }
            }
        }
        Section {
            Link(destination: URL(string: "https://www.asmr.one/work/\(self.source_id)")!) {
                Label("在浏览器中打开", systemImage: "safari")
            }
            ShareLink("分享作品...", item: URL(string: "https://www.asmr.one/work/\(self.source_id)")!)
        }
    }
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
    
    struct Rank: Codable {
        var term: String
        var category: String
        var rank: Int
        var rank_date: String
    }
    struct VA: Identifiable, Hashable, Codable {
        var id: UUID
        var name: String
    }
    struct Tag: Identifiable, Hashable, Codable {
        var id: Int
        var name: String
        var upvote: Int?
        var downvote: Int?
        var voteRank: Int?
        var voteStatus: Int?
    }
    struct LanguageEditionInDB: Identifiable, Codable {
        var id: Int
        var lang: String
        var title: String
        var source_id: String
        var is_original: Bool
        var source_type: String
    }
    struct TranslationInfo: Codable {
        var lang: String?
        var is_child: Bool
        var is_parent: Bool
        var is_original: Bool
        var is_volunteer: Bool
        var child_worknos: [String]
        var parent_workno: String?
        var original_workno: String?
        var is_translation_agree: Bool
        var is_translation_bonus_child: Bool
    }
}

struct TrackStructure: Equatable, Hashable, Codable {
    var type: FileType
    var hash: String?
    var title: String
    var workTitle: String?
    var mediaStreamUrl: String?
    var mediaDownloadUrl: String?
    var duration: Double?
    var size: UInt64?
    var children: [TrackStructure]?
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.type == rhs.type && lhs.hash == rhs.hash && lhs.title == rhs.title && lhs.workTitle == rhs.workTitle && lhs.duration == rhs.duration && lhs.size == rhs.size
    }
    
    enum FileType: String, Codable {
        case folder
        case audio
        case text
        case image
        case other
    }
}
extension Array<TrackStructure> {
    var flattened: [TrackStructure] {
        var result: [TrackStructure] = []
        for track in self {
            result.append(track)
            if let children = track.children {
                result.append(contentsOf: children.flattened)
            }
        }
        return result
    }
}

struct NowPlayingInfo: Codable {
    var sourceWork: Work
    var sourceTracks: [TrackStructure]
    var playURL: String
    var playFileName: String
    var lyrics: [ClosedRange<Double>: String]?
    var preventAutoPlaying: Bool = false
}

enum SearchToken: Identifiable, Hashable, Codable {
    case tag(String)
    case circle(String)
    case va(String)
    case duration(String)
    case rate(String)
    case price(String)
    case sell(String)
    case age(String)
    case lang(String)
    case antiTag(String)
    case antiDuration(String)
    case antiCircle(String)
    case antiVA(String)
    case antiAge(String)
    case antiLang(String)
    
    var id: String {
        switch self {
        case .tag(let string): string
        case .circle(let string): string
        case .va(let string): string
        case .duration(let string): string
        case .rate(let string): string
        case .price(let string): string
        case .sell(let string): string
        case .age(let string): string
        case .lang(let string): string
        case .antiTag(let string): string
        case .antiDuration(let string): string
        case .antiCircle(let string): string
        case .antiVA(let string): string
        case .antiAge(let string): string
        case .antiLang(let string): string
        }
    }
    
    var representingSymbol: String {
        switch self {
        case .tag: "tag"
        case .circle: "person.3"
        case .va: "person"
        case .duration: "clock"
        case .rate: "star.leadinghalf.filled"
        case .price: "dollarsign"
        case .sell: "checkmark.rectangle.stack"
        case .age: "figure.and.child.holdinghands"
        case .lang: "globe"
        case .antiTag: "tag.slash"
        case .antiDuration: "clock.badge.questionmark"
        case .antiCircle: "person.2.slash"
        case .antiVA: "person.slash"
        case .antiAge: "figure.child.and.lock"
        case .antiLang: "globe.badge.chevron.backward"
        }
    }
    
    var searchPrompt: String {
        switch self {
        case .tag(let string): "$tag:\(string)$ "
        case .circle(let string): "$circle:\(string)$ "
        case .va(let string): "$va:\(string)$ "
        case .duration(let string): "$duration:\(string)$ "
        case .rate(let string): "$rate:\(string)$ "
        case .price(let string): "$price:\(string)$ "
        case .sell(let string): "$sell:\(string)$ "
        case .age(let string): "$age:\(string)$ "
        case .lang(let string): "$lang:\(string)$ "
        case .antiTag(let string): "$-tag:\(string)$ "
        case .antiDuration(let string): "$-duration:\(string)$ "
        case .antiCircle(let string): "$-circle:\(string)$ "
        case .antiVA(let string): "$-va:\(string)$ "
        case .antiAge(let string): "$-age:\(string)$ "
        case .antiLang(let string): "$-lang:\(string)$ "
        }
    }
}

struct RecentSearchItem: Identifiable, Hashable, Equatable, Codable {
    var id: UUID = UUID()
    var tokens: [SearchToken]
    var text: String
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.tokens == rhs.tokens && lhs.text == rhs.text
    }
}

struct DownloadWorkBundleInfo: Codable {
    var bundleVersion: Int = 1
    var work: Work
    var tracks: [TrackStructure]
    var dateCreated: Date
}
