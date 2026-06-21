//
//  LyricParsers.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import OSLog
import Foundation

func parseVTT(_ content: String) -> [ClosedRange<Double>: String] {
    var result = [ClosedRange<Double>: String]()
    
    let lines = content.components(separatedBy: .newlines)
    
    var currentStart: Double?
    var currentEnd: Double?
    var currentText = ""
    
    let timePattern = #"(\d{2}):(\d{2}):(\d{2})\.(\d{3}) --> (\d{2}):(\d{2}):(\d{2})\.(\d{3})"#
    let timeRegex = try! NSRegularExpression(pattern: timePattern)
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // 保存当前句子
            if let start = currentStart, let end = currentEnd {
                result[start...end] = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            // 重置
            currentStart = nil
            currentEnd = nil
            currentText = ""
            continue
        }
        
        // 判断是否是时间行
        if let match = timeRegex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) {
            func timeComponent(_ rangeIndex: Int) -> Double {
                let range = match.range(at: rangeIndex)
                if let swiftRange = Range(range, in: trimmed) {
                    return Double(trimmed[swiftRange]) ?? 0
                }
                return 0
            }
            
            let start = timeComponent(1) * 3600 + timeComponent(2) * 60 + timeComponent(3) + timeComponent(4) / 1000
            let end = timeComponent(5) * 3600 + timeComponent(6) * 60 + timeComponent(7) + timeComponent(8) / 1000
            
            currentStart = start
            currentEnd = end
        } else if currentStart != nil && currentEnd != nil {
            currentText += (currentText.isEmpty ? "" : "\n") + trimmed
        }
    }
    
    if let start = currentStart, let end = currentEnd {
        result[start...end] = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    return result
}

func parseLRC(_ content: String) -> [ClosedRange<Double>: String] {
    struct LRCLine {
        let time: Double
        var endTime: Double?
        let text: String
    }
    
    var lines: [LRCLine] = []
    let pattern = #"\[(\d{2}):(\d{2})\.(\d{2})\](.*)"#
    let regex = try! NSRegularExpression(pattern: pattern)
    
    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { continue }
        
        if let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) {
            func timeComponent(_ idx: Int) -> Double {
                let range = match.range(at: idx)
                guard let swiftRange = Range(range, in: trimmed) else { return 0 }
                return Double(trimmed[swiftRange]) ?? 0
            }
            
            let minutes = timeComponent(1)
            let seconds = timeComponent(2)
            let hundredths = timeComponent(3)
            let time = minutes * 60 + seconds + hundredths / 100
            
            let lyricRange = match.range(at: 4)
            let text = lyricRange.location != NSNotFound ? String(trimmed[Range(lyricRange, in: trimmed)!]).trimmingCharacters(in: .whitespaces) : ""
            
            if text.isEmpty && !lines.isEmpty {
                lines[lines.count - 1].endTime = time
            } else {
                lines.append(LRCLine(time: time, text: text))
            }
        }
    }
    
    var result: [ClosedRange<Double>: String] = [:]
    
    for (index, line) in lines.enumerated() {
        let start = line.time
        let end: Double
        if let endTime = line.endTime {
            end = endTime
        } else if index + 1 < lines.count {
            end = lines[index + 1].time
        } else {
            end = start + 5.0
        }
        result[start...end] = line.text
    }
    
    return result
}

func _locateLyricFile(
    for audioTrack: TrackStructure,
    in allTracks: [TrackStructure]
) -> (track: TrackStructure, fileTypeHint: String)? {
    let allFiles = allTracks.flattened
    for file in allFiles {
        if file.title == "\(audioTrack.title).vtt"
            || file.title == "\(audioTrack.title.dropLast(4)).vtt" {
            return (file, "vtt")
        } else if file.title == "\(audioTrack.title).lrc"
                    || file.title == "\(audioTrack.title.dropLast(4)).lrc" {
            return (file, "lrc")
        }
    }
    return nil
}

func parseLyrics(
    for audioTrack: TrackStructure,
    in allTracks: [TrackStructure]
) async -> [ClosedRange<Double>: String]? {
    guard let (track, fileTypeHint) = _locateLyricFile(
        for: audioTrack,
        in: allTracks
    ), let url = URL(string: track.mediaStreamUrl ?? "") else {
        return nil
    }
    guard let (data, _) = try? await URLSession.shared.data(from: url) else {
        return nil
    }
    
    let respStr: String
    if let str = String(data: data, encoding: .utf8) {
        respStr = str
    } else if let str = String(
        data: data,
        encoding: .init(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        ))
    ) {
        os_log(.error, "Cannot parse lyrics data as UTF8, using GB18030")
        respStr = str
    } else {
        os_log(.fault, "Cannot convert lyrics data to String")
        return nil
    }
    
    switch fileTypeHint {
    case "vtt":
        return parseVTT(respStr)
    case "lrc":
        return parseLRC(respStr)
    default: return nil
    }
}
