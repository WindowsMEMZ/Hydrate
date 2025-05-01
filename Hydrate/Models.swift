//
//  Models.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import SwiftUI

struct Pagination: Decodable {
    var currentPage: Int
    var pageSize: Int
    var totalCount: Int
}

struct Work: Identifiable, Codable {
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
    struct Tag: Identifiable, Codable {
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
        var translation_bonus_langs: [String]
        var is_translation_bonus_child: Bool
    }
}

struct TrackStructure: Hashable, Decodable {
    var type: FileType
    var hash: String?
    var title: String
    var workTitle: String?
    var mediaStreamUrl: String?
    var mediaDownloadUrl: String?
    var duration: Double?
    var size: UInt64?
    var children: [TrackStructure]?
    
    enum FileType: String, Decodable {
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
