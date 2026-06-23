//
//  FileTrackContentView.swift
//  Hydrate
//
//  Created by memz233 on 6/23/26.
//

import OSLog
import SwiftUI
import NotifKit
import SafariServices
import SDWebImageSwiftUI
@_spi(Advanced) import SwiftUIIntrospect

struct FileTrackContentView: View {
    var track: TrackStructure
    var work: Work
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Group {
            switch track.type {
            case .text:
                TextTrackContentView(url: URL(
                    string: DownloadManager.shared.contentURL(track: track, of: work)?.absoluteString
                    ?? track.mediaStreamUrl ?? ""
                ))
            case .image:
                ImageTrackContentView(url: URL(
                    string: DownloadManager.shared.contentURL(track: track, of: work)?.absoluteString
                    ?? track.mediaStreamUrl ?? ""
                ))
            case .other:
                OtherTrackContentView(url: URL(
                    string: DownloadManager.shared.contentURL(track: track, of: work)?.absoluteString
                    ?? track.mediaStreamUrl ?? ""
                ))
            default: EmptyView()
            }
        }
        .navigationTitle(track.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭", systemImage: "xmark") {
                    dismiss()
                }
            }
        }
    }
}

private struct TextTrackContentView: View {
    var url: URL?
    @State private var content: String?
    @State private var isFailedToLoadContent = false
    var body: some View {
        if let url, !isFailedToLoadContent {
            if let content {
                TextEditor(text: .constant(content))
                    .introspect(.textEditor, on: .iOS(.v26...)) { textView in
                        textView.isEditable = false
                        textView.isSelectable = true
                    }
            } else {
                ProgressView()
                    .controlSize(.large)
                    .onAppear {
                        Task {
                            await loadContent(url)
                        }
                    }
            }
        } else {
            TrackContentErrorView()
        }
    }
    
    private func loadContent(_ url: URL) async {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
            isFailedToLoadContent = true
            return
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
            respStr = str
        } else if let str = String(data: data, encoding: .utf16) {
            respStr = str
        } else {
            os_log(.fault, """
            Failed to decode string from content of URL: \(url.absoluteString)
            """)
            isFailedToLoadContent = true
            return
        }
        
        content = respStr
    }
}

private struct ImageTrackContentView: View {
    var url: URL?
    @State private var platformImage: PlatformImage?
    var body: some View {
        if let url {
            WebImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
                    .controlSize(.large)
            }
            .onSuccess { image, _, _ in
                platformImage = image
            }
            .toolbar {
                if let platformImage {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("存储到相册", systemImage: "square.and.arrow.down") {
                            UIImageWriteToSavedPhotosAlbum(platformImage, nil, nil, nil)
                            NKTipper.automaticStyle.present(text: "已存储", symbol: "checkmark.circle.fill")
                        }
                    }
                }
            }
        } else {
            TrackContentErrorView()
        }
    }
}

private struct OtherTrackContentView: View {
    var url: URL?
    var body: some View {
        if let url {
            GenericUIViewControllerRepresentable(viewController: {
                let controller = SFSafariViewController(url: url)
                return controller
            }())
            .ignoresSafeArea()
            .toolbarVisibility(.hidden, for: .navigationBar)
        } else {
            TrackContentErrorView()
        }
    }
}

private struct TrackContentErrorView: View {
    var body: some View {
        ContentUnavailableView("载入内容时出错", systemImage: "xmark.octagon.fill")
    }
}
