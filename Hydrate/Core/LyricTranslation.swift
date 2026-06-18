//
//  LyricTranslation.swift
//  Hydrate
//
//  Created by memz233 on 6/17/26.
//

import SwiftUI
import Translation

final class LyricTranslation {
    static let shared = LyricTranslation()
    
    private init() {}
    
    @AppStorage("TranscriptionTranslationTarget")
    private var transcriptionTranslationTarget = ""
    
    private var translationCache: [
        String /* targetLanguage */
        : [String /* sourceText */: String /* targetText */]
    ] = [:]
    
    func translate(_ contents: [String]) async -> [String?]? {
        let session = TranslationSession(
            installedSource: .init(identifier: "ja"),
            target: targetLanguage
        )
        
        var result: [String?] = Array(repeating: nil, count: contents.count)
        
        for (index, content) in contents.enumerated() {
            if let cachedResult = translationCache[
                transcriptionTranslationTarget
            ]?[content] {
                result[index] = cachedResult
            }
        }
        
        if result.allSatisfy({ $0 != nil }) {
            return result
        }
        
        let requests = contents.enumerated().compactMap {
            result[$0] == nil ? TranslationSession.Request(sourceText: $1) : nil
        }
        
        do {
            let translations = try await session.translations(from: requests)
            for (index, content) in contents.enumerated() {
                if let translation = translations.first(where: {
                    $0.sourceText == content
                }) {
                    result[index] = translation.targetText
                    var currentCache: [String: String]! = translationCache[
                        transcriptionTranslationTarget
                    ]
                    if currentCache == nil { currentCache = [:] }
                    currentCache.updateValue(
                        translation.targetText,
                        forKey: translation.sourceText
                    )
                    translationCache.updateValue(
                        currentCache,
                        forKey: transcriptionTranslationTarget
                    )
                }
            }
            return result
        } catch {
            return nil
        }
    }
    
    func translate(_ content: String) async -> String? {
        let results = await translate([content])
        return results?.first ?? nil
    }
    
    private var targetLanguage: Locale.Language? {
        Self._language(fromTarget: transcriptionTranslationTarget)
    }
}

extension LyricTranslation {
    static func _language(fromTarget target: String) -> Locale.Language? {
        if target.isEmpty {
            return nil
        }
        
        return .init(identifier: target)
    }
}
