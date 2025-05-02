//
//  DownloadManager.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/2.
//

import Alamofire
import Foundation

class DownloadManager {
    static let shared = DownloadManager()
    
    private init() {
        if !FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Documents/Downloads") {
            try? FileManager.default.createDirectory(atPath: NSHomeDirectory() + "/Documents/Downloads", withIntermediateDirectories: true)
        }
    }
    
    private var taskTable: [Int: [DownloadRequest]] = [:]
    
    func createTask(for work: Work, withTracks tracks: [TrackStructure]) throws {
        func createTask(for tracks: inout [TrackStructure], at path: String) throws -> [DownloadRequest] {
            var requests = [DownloadRequest]()
            for (index, track) in tracks.enumerated() {
                switch track.type {
                case .folder:
                    try FileManager.default.createDirectory(atPath: path + "/\(track.title)", withIntermediateDirectories: false)
                    if var children = track.children {
                        requests.append(contentsOf: try createTask(for: &children, at: path + "/\(track.title)"))
                        tracks[index].children = children
                    }
                default:
                    if let url = track.mediaDownloadUrl {
                        let destination: DownloadRequest.Destination = { _, _ in
                            return (URL(fileURLWithPath: path + "/\(track.title)"), [.removePreviousFile, .createIntermediateDirectories])
                        }
                        let request = AF.download(url, to: destination)
                        request.response { _ in
                            
                        }
                        requests.append(request)
                        tracks[index].mediaStreamUrl = URL(filePath: path + "/\(track.title)").absoluteString
                    }
                }
            }
            return requests
        }
        
        let id = UUID().uuidString
        let bundlePath = NSHomeDirectory() + "/Documents/Downloads/\(id).bundle"
        try FileManager.default.createDirectory(atPath: bundlePath, withIntermediateDirectories: true)
        var mutableTracks = tracks
        let requests = try createTask(for: &mutableTracks, at: bundlePath)
        let info = DownloadWorkBundleInfo(work: work, tracks: tracks, dateCreated: .now)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try encoder.encode(info).write(to: URL(filePath: bundlePath + "/Info.plist"))
        taskTable.updateValue(requests, forKey: work.id)
    }
    func cancelTask(for id: Int) {
        taskTable[id]?.forEach { $0.cancel() }
        taskTable.removeValue(forKey: id)
        remove(id: id)
    }
    func progress(for id: Int) -> Double? {
        if let requests = taskTable[id] {
            var completes: Int64 = 0
            var totals: Int64 = 0
            for request in requests {
                completes += request.isFinished ? request.downloadProgress.totalUnitCount : request.downloadProgress.completedUnitCount
                totals += request.downloadProgress.totalUnitCount
            }
            return Double(completes) / Double(totals)
        }
        return nil
    }
    func downloadedWorks() -> [Work] {
        allBundles().sorted { $0.dateCreated > $1.dateCreated }.map { $0.work }
    }
    func isDownloaded(for id: Int) -> Bool {
        if let progress = progress(for: id), progress < 1 {
            return false
        }
        return allBundles().contains { $0.work.id == id }
    }
    func remove(id: Int) {
        guard FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Documents/Downloads") else {
            return
        }
        let decoder = PropertyListDecoder()
        for file in (try? FileManager.default.contentsOfDirectory(atPath: NSHomeDirectory() + "/Documents/Downloads")) ?? [] where !file.hasPrefix(".") && file.hasSuffix(".bundle") {
            let infoFilePath = NSHomeDirectory() + "/Documents/Downloads/\(file)/Info.plist"
            if FileManager.default.fileExists(atPath: infoFilePath) {
                if let _fileData = try? Data(contentsOf: URL(filePath: infoFilePath)),
                   let info = try? decoder.decode(DownloadWorkBundleInfo.self, from: _fileData),
                   info.work.id == id {
                    try? FileManager.default.removeItem(atPath: NSHomeDirectory() + "/Documents/Downloads/\(file)")
                }
            }
        }
    }
    func work(of id: Int) -> Work? {
        allBundles().first { $0.work.id == id }?.work
    }
    func tracks(of id: Int) -> [TrackStructure]? {
        allBundles().first { $0.work.id == id }?.tracks
    }
    
    private func allBundles() -> [DownloadWorkBundleInfo] {
        guard FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Documents/Downloads") else {
            return []
        }
        var result = [DownloadWorkBundleInfo]()
        let decoder = PropertyListDecoder()
        for file in (try? FileManager.default.contentsOfDirectory(atPath: NSHomeDirectory() + "/Documents/Downloads")) ?? [] where !file.hasPrefix(".") && file.hasSuffix(".bundle") {
            let infoFilePath = NSHomeDirectory() + "/Documents/Downloads/\(file)/Info.plist"
            if FileManager.default.fileExists(atPath: infoFilePath) {
                if let _fileData = try? Data(contentsOf: URL(filePath: infoFilePath)),
                   let info = try? decoder.decode(DownloadWorkBundleInfo.self, from: _fileData) {
                    result.append(info)
                }
            }
        }
        return result
    }
}
