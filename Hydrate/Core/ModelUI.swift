//
//  ModelUI.swift
//  Hydrate
//
//  Created by memz233 on 6/22/26.
//

import SwiftUI
import NotifKit
import Alamofire
import DarockFoundation
import SDWebImageSwiftUI

struct _WorkPreviewView: View {
    var work: Work
    var body: some View {
        VStack(alignment: .leading) {
            WebImage(url: URL(string: work.mainCoverUrl)) { image in
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
                Text(work.title)
                    .font(.system(size: 16, weight: .semibold))
                Text(work.vas.map { $0.name }.joined(separator: "/"))
                    .foregroundStyle(.gray)
                Spacer()
                    .frame(height: 3)
                Text(work.tags.map(\.name).joined(separator: " · "))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal)
        }
        .frame(width: UIScreen.main.bounds.width - 70, height: UIScreen.main.bounds.width + 40)
    }
}

struct _WorkContextActions: View {
    var work: Work
    @AppStorage("AccountToken") private var accountToken = ""
    @AppStorage("AudioTypePreferencesHaveReviewed") private var preferencesHaveReviewed = false
    var body: some View {
        Section {
            if !accountToken.isEmpty {
                if work.userRating != nil {
                    Button("从收藏中移除", systemImage: "trash", role: .destructive) {
                        requestJSON(
                            "https://api.asmr.one/api/review?work_id=\(work.id)",
                            method: .delete,
                            headers: globalRequestHeaders
                        ) { _, isSuccess in
                            if isSuccess {
                                LibraryCache.shared.removeFavorite(work)
                            } else {
                                NKTipper.automaticStyle.present(text: "移除时出错", symbol: "xmark.circle.fill")
                            }
                            
                        }
                    }
                } else {
                    Button("收藏", systemImage: "star") {
                        requestJSON(
                            "https://api.asmr.one/api/review",
                            method: .put,
                            parameters: ["work_id": work.id, "rating": 5, "review_text": nil, "progress": nil],
                            encoding: JSONEncoding.default,
                            headers: globalRequestHeaders
                        ) { _, isSuccess in
                            if isSuccess {
                                LibraryCache.shared.addFavorite(work)
                                NKTipper.automaticStyle.present(text: "已添加到收藏", symbol: "checkmark.circle.fill")
                            } else {
                                NKTipper.automaticStyle.present(text: "收藏时出错", symbol: "xmark.circle.fill")
                            }
                        }
                    }
                }
            }
            if !DownloadManager.shared.isDownloaded(workID: work.id) {
                Button("下载全部音频", systemImage: "arrow.down.circle") {
                    if !preferencesHaveReviewed,
                       let scene = UIApplication.shared.connectedScenes.activeWindowScene,
                       let window = scene.keyWindow {
                        let controller = UIHostingController(rootView: NavigationStack {
                            EnvironmentReader(\.dismiss) { dismiss in
                                AudioTypePreferencesView()
                                    .toolbar {
                                        ToolbarItem(placement: .topBarTrailing) {
                                            Button("确认", systemImage: "checkmark") {
                                                dismiss()
                                                preferencesHaveReviewed = true
                                                downloadAll()
                                            }
                                            .buttonStyle(.glassProminent)
                                        }
                                    }
                            }
                        }.interactiveDismissDisabled())
                        window.rootViewController?.present(controller, animated: true)
                    } else {
                        downloadAll()
                    }
                }
            } else {
                Button("移除全部音频", systemImage: "xmark.circle", role: .destructive) {
                    DownloadManager.shared.removeAllTracks(of: work)
                }
            }
        }
        Section {
            Link(destination: URL(string: "https://www.asmr.one/work/\(work.source_id)")!) {
                Label("在浏览器中打开", systemImage: "safari")
            }
            if let media = AudioPlayer.shared.media, media.sourceWork == work {
                ShareLink("分享作品...", item: media, preview: media.sharePreview)
            } else {
                ShareLink("分享作品...", item: URL(string: "https://www.asmr.one/work/\(work.source_id)")!)
            }
        }
    }
    
    private func downloadAll() {
        requestString(
            "https://api.asmr.one/api/tracks/\(work.id)?v=1",
            headers: globalRequestHeaders
        ) { respStr, isSuccess in
            if isSuccess,
               let tracks = getJsonData([TrackStructure].self, from: respStr) {
                DownloadManager.shared.downloadAll(tracks, of: work)
            }
        }
    }
}
