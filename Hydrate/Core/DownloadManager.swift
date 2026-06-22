//
//  DownloadManager.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/2.
//

import OSLog
import UIKit
import SwiftUI
import Foundation

final class DownloadManager: NSObject {
    static let shared = DownloadManager()
    
    private var sharedDownloadingSession: URLSession!
    
    private override init() {
        super.init()
        
        if !FileManager.default.fileExists(
            atPath: NSHomeDirectory() + "/Documents/Downloads"
        ) {
            try? FileManager.default.createDirectory(
                atPath: NSHomeDirectory() + "/Documents/Downloads",
                withIntermediateDirectories: true
            )
        }
        if !FileManager.default.fileExists(
            atPath: NSHomeDirectory() + "/Documents/Downloads/Metadata"
        ) {
            try? FileManager.default.createDirectory(
                atPath: NSHomeDirectory() + "/Documents/Downloads/Metadata",
                withIntermediateDirectories: false
            )
        }
        
        let downloadingSessionConfig = URLSessionConfiguration.background(
            withIdentifier: "com.memz233.Hydrate.Work-Download"
        )
        downloadingSessionConfig.isDiscretionary = false
        downloadingSessionConfig.sessionSendsLaunchEvents = true
        downloadingSessionConfig.allowsCellularAccess = false
        downloadingSessionConfig.waitsForConnectivity = true
        self.sharedDownloadingSession = .init(
            configuration: downloadingSessionConfig,
            delegate: self,
            delegateQueue: nil
        )
    }
    
    private var taskTable: [Int: DownloadMetadata] = [:]
    @AppStorage("DownloadSubtitleWithAudio")
        private var downloadSubtitleWithAudio = true
    
    var downloadingTracks: [(TrackStructure, Int)] {
        taskTable.map { key, value in
            (value.track, key)
        }
    }
    
    @discardableResult
    func download(
        track: TrackStructure,
        of work: Work,
        allTracks: [TrackStructure]
    ) -> Int? {
        guard let _urlString = track.mediaDownloadUrl ?? track.mediaStreamUrl,
              let url = URL(string: _urlString) else {
            return nil
        }
        
        let task = sharedDownloadingSession.downloadTask(with: url)
        if let size = track.size {
            task.countOfBytesClientExpectsToReceive = Int64(size) + 1024
        }
        taskTable.updateValue(.init(
            task: task,
            track: track,
            work: work,
            allTracks: allTracks
        ), forKey: task.taskIdentifier)
        task.resume()
        
        // Metadata can be fetched quickly
        Task {
            guard !hasMetadata(ofWorkID: work.id) else { return }
            guard !taskTable.values.contains(where: { $0.work == work }) else {
                return
            }
            await withTaskGroup { group in
                group.addTask {
                    if let url = URL(string: work.mainCoverUrl) {
                        return (0, try? await URLSession.shared.data(from: url))
                    } else {
                        return (0, nil)
                    }
                }
                group.addTask {
                    if let url = URL(string: work.samCoverUrl) {
                        return (1, try? await URLSession.shared.data(from: url))
                    } else {
                        return (1, nil)
                    }
                }
                group.addTask {
                    if let url = URL(string: work.thumbnailCoverUrl) {
                        return (2, try? await URLSession.shared.data(from: url))
                    } else {
                        return (2, nil)
                    }
                }
                
                for await (type, result) in group {
                    let destination: URL
                    switch type {
                    case 0:
                        destination = URL(
                            filePath: NSHomeDirectory()
                            + "/Documents/Downloads/Metadata/\(work.id)_mainCover.png"
                        )
                    case 1:
                        destination = URL(
                            filePath: NSHomeDirectory()
                            + "/Documents/Downloads/Metadata/\(work.id)_samCover.png"
                        )
                    case 2:
                        destination = URL(
                            filePath: NSHomeDirectory()
                            + "/Documents/Downloads/Metadata/\(work.id)_thumbnailCover.png"
                        )
                    default: continue
                    }
                    
                    guard let data = result?.0 else { continue }
                    try? data.write(to: destination)
                }
            }
        }
        
        if downloadSubtitleWithAudio && track.type == .audio,
           let (fileTrack, _) = _locateLyricFile(for: track, in: allTracks) {
            download(track: fileTrack, of: work, allTracks: allTracks)
        }
        
        return task.taskIdentifier
    }
    func cancelTask(for id: Int) {
        taskTable[id]?.task.cancel()
        taskTable.removeValue(forKey: id)
    }
    func progress(for id: Int) -> Double? {
        if let metadata = taskTable[id] {
            return metadata.task.progress.fractionCompleted
        }
        return nil
    }
    
    func downloadedWorks() -> [Work] {
        allBundles()
            .sorted { $0.dateModified > $1.dateModified }
            .map { $0.work }
    }
    func isDownloaded(workID id: Int) -> Bool {
        FileManager.default.fileExists(
            atPath: NSHomeDirectory() + "/Documents/Downloads/WK\(id).bundle"
        )
    }
    func remove(track: TrackStructure, of work: Work) {
        let trackHash = track.stableHashValue
        let bundlePath = NSHomeDirectory()
            + "/Documents/Downloads/WK\(work.id).bundle"
        let trackPath = bundlePath + "/\(trackHash).data"
        
        if FileManager.default.fileExists(atPath: trackPath) {
            try? FileManager.default.removeItem(atPath: trackPath)
            
            if let _fileData = try? Data(
                contentsOf: URL(filePath: bundlePath + "/Info.plist")
            ), var info = try? PropertyListDecoder().decode(
                DownloadWorkBundleInfo.self,
                from: _fileData
            ) {
                info.availableTracks.removeValue(forKey: trackHash)
                info.dateModified = .now
                
                if !info.availableTracks.isEmpty {
                    let encoder = PropertyListEncoder()
                    encoder.outputFormat = .binary
                    try? encoder.encode(info).write(
                        to: URL(filePath: bundlePath + "/Info.plist")
                    )
                } else {
                    // Remove the entire bundle if no track is available
                    try? FileManager.default.removeItem(atPath: bundlePath)
                }
            }
        }
    }
    func bundleInfo(of id: Int) -> DownloadWorkBundleInfo? {
        let infoPath = NSHomeDirectory()
            + "/Documents/Downloads/WK\(id).bundle/Info.plist"
        guard FileManager.default.fileExists(atPath: infoPath) else {
            return nil
        }
        
        if let data = try? Data(contentsOf: URL(filePath: infoPath)),
           var result = try? PropertyListDecoder().decode(
            DownloadWorkBundleInfo.self,
            from: data
        ) {
            replaceWorkMetadataLink(&result.work)
            return result
        }
        return nil
    }
    func contentURL(track: TrackStructure, of work: Work) -> URL? {
        let trackHash = track.stableHashValue
        let trackPath = NSHomeDirectory()
            + "/Documents/Downloads/WK\(work.id).bundle/\(trackHash).data"
        
        if FileManager.default.fileExists(atPath: trackPath) {
            return URL(filePath: trackPath)
        } else {
            return nil
        }
    }
    
    private func allBundles() -> [DownloadWorkBundleInfo] {
        guard FileManager.default.fileExists(
            atPath: NSHomeDirectory() + "/Documents/Downloads"
        ) else {
            return []
        }
        
        var result = [DownloadWorkBundleInfo]()
        let decoder = PropertyListDecoder()
        for file in (try? FileManager.default.contentsOfDirectory(
            atPath: NSHomeDirectory() + "/Documents/Downloads"
        )) ?? [] where file.hasPrefix("WK") && file.hasSuffix(".bundle") {
            let infoFilePath = NSHomeDirectory()
            + "/Documents/Downloads/\(file)/Info.plist"
            
            if FileManager.default.fileExists(atPath: infoFilePath) {
                if let _fileData = try? Data(
                    contentsOf: URL(filePath: infoFilePath)
                ), var info = try? decoder.decode(
                    DownloadWorkBundleInfo.self,
                    from: _fileData
                ) {
                    replaceWorkMetadataLink(&info.work)
                    result.append(info)
                }
            }
        }
        return result
    }
    private func hasMetadata(ofWorkID id: Int) -> Bool {
        FileManager.default.fileExists(
            atPath: NSHomeDirectory()
                + "/Documents/Downloads/Metadata/\(id)_mainCover.png"
        ) || FileManager.default.fileExists(
            atPath: NSHomeDirectory()
                + "/Documents/Downloads/Metadata/\(id)_samCover.png"
        ) || FileManager.default.fileExists(
            atPath: NSHomeDirectory()
                + "/Documents/Downloads/Metadata/\(id)_thumbnailCover.png"
        )
    }
    private func replaceWorkMetadataLink(_ work: inout Work) {
        let mainCoverPath = NSHomeDirectory()
            + "/Documents/Downloads/Metadata/\(work.id)_mainCover.png"
        let samCoverPath = NSHomeDirectory()
            + "/Documents/Downloads/Metadata/\(work.id)_samCover.png"
        let thumbnailCoverPath = NSHomeDirectory()
            + "/Documents/Downloads/Metadata/\(work.id)_thumbnailCover.png"
        if FileManager.default.fileExists(atPath: mainCoverPath) {
            work.mainCoverUrl = URL(filePath: mainCoverPath).absoluteString
        }
        if FileManager.default.fileExists(atPath: samCoverPath) {
            work.samCoverUrl = URL(filePath: samCoverPath).absoluteString
        }
        if FileManager.default.fileExists(atPath: thumbnailCoverPath) {
            work.thumbnailCoverUrl = URL(filePath: thumbnailCoverPath)
                .absoluteString
        }
    }
    
    private struct DownloadMetadata {
        var task: URLSessionDownloadTask
        var track: TrackStructure
        var work: Work
        var allTracks: [TrackStructure]
    }
}

@MainActor
private var backgroundCompletionHandler: (() -> Void)?

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        DispatchQueue.main.async {
            backgroundCompletionHandler?()
            backgroundCompletionHandler = nil
        }
    }
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let metadata = taskTable[downloadTask.taskIdentifier] else {
            os_log(.fault, """
            A download task finished and calling the delegate method, \
            but no associated metadata was found for this task
            """)
            return
        }
        
        defer {
            taskTable.removeValue(forKey: downloadTask.taskIdentifier)
        }
        
        do {
            let workID = metadata.work.id
            let bundleURL = URL(
                filePath: NSHomeDirectory()
                + "/Documents/Downloads/WK\(workID).bundle"
            )
            if !FileManager.default.fileExists(atPath: bundleURL.path) {
                try FileManager.default.createDirectory(
                    at: bundleURL,
                    withIntermediateDirectories: true
                )
            }
            
            let trackHash = metadata.track.stableHashValue
            
            let bundleInfo: DownloadWorkBundleInfo
            if let content = try? Data(
                contentsOf: bundleURL.appending(path: "Info.plist")
            ), var info = try? PropertyListDecoder().decode(
                DownloadWorkBundleInfo.self,
                from: content
            ) {
                info.availableTracks.updateValue(
                    metadata.track,
                    forKey: trackHash
                )
                info.dateModified = .now
                bundleInfo = info
            } else {
                bundleInfo = .init(
                    work: metadata.work,
                    allTracks: metadata.allTracks,
                    availableTracks: [trackHash: metadata.track],
                    dateCreated: .now,
                    dateModified: .now
                )
            }
            
            try FileManager.default.moveItem(
                at: location,
                to: bundleURL.appending(path: "\(trackHash).data")
            )
            
            // Update info plist last to prevent problems when failed to
            // move contents
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            try encoder.encode(bundleInfo).write(
                to: bundleURL.appending(path: "Info.plist")
            )
            
            os_log(.info, """
            Track '\(metadata.track.title) has finished downloading'
            """)
        } catch {
            os_log(.fault, """
            Post track downloading action failed with error: \(error)
            """)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        if let error {
            taskTable.removeValue(forKey: task.taskIdentifier)
            os_log(.error, "\(error)")
        }
    }
}

extension AppDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        if identifier == "com.memz233.Hydrate.Work-Download" {
            backgroundCompletionHandler = completionHandler
        }
    }
}

// MARK: Storage Management
extension DownloadManager {
    func contentTotalSize() -> Int64 {
        folderSize(
            at: URL(filePath: NSHomeDirectory() + "/Documents/Downloads")
        )
    }
    
    func workContentSize(_ work: Work) -> Int64 {
        folderSize(at: URL(
            filePath: NSHomeDirectory()
                + "/Documents/Downloads/WK\(work.id).bundle"
        ))
    }
    
    func tracksWithSize(of work: Work) -> [(TrackStructure, Int64)] {
        guard let bundle = bundleInfo(of: work.id) else { return [] }
        
        let bundleURL = URL(
            filePath: NSHomeDirectory()
                + "/Documents/Downloads/WK\(work.id).bundle"
        )
        return bundle.availableTracks.map { key, value in
            (value,
             Int64((try? bundleURL
                .appending(path: "\(key).data")
                .resourceValues(forKeys: [.fileSizeKey])
                .fileSize) ?? 0))
        }.sorted { $0.1 > $1.1 }
    }
    
    private func folderSize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]
        ) else { return 0 }
        
        var result: Int64 = 0
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(
                forKeys: [.fileSizeKey, .isDirectoryKey]
            ), resourceValues.isDirectory == false else { continue }
            
            result += Int64(resourceValues.fileSize ?? 0)
        }
        
        return result
    }
}
