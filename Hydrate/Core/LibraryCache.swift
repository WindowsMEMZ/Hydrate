//
//  LibraryCache.swift
//  Hydrate
//
//  Created by memz233 on 6/24/26.
//

import Foundation

final class LibraryCache {
    static let shared = LibraryCache()
    
    private(set) var favoriteWorks: [Work] = []
    
    private init() {
        if let _data = try? Data(contentsOf: URL(
            filePath: NSTemporaryDirectory() + "/LibraryCache.plist"
        )), let contents = try? PropertyListDecoder().decode(
            [String: [Work]].self,
            from: _data
        ) {
            if let favorite = contents["Favorites"] {
                favoriteWorks = favorite
            }
        }
    }
    
    func updateFavorites(_ works: [Work]) {
        favoriteWorks = works
        writeCache()
    }
    func addFavorite(_ work: Work) {
        favoriteWorks.insert(work, at: 0)
        writeCache()
    }
    func removeFavorite(_ work: Work) {
        favoriteWorks.removeAll {
            $0 == work
        }
        writeCache()
    }
    
    private func writeCache() {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try? encoder.encode([
            "Favorites": favoriteWorks
        ]).write(
            to: URL(filePath: NSTemporaryDirectory() + "/LibraryCache.plist")
        )
    }
}
