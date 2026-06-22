//
//  StorageManagementView.swift
//  Hydrate
//
//  Created by memz233 on 6/19/26.
//

import SwiftUI
import SDWebImageSwiftUI

private let formatter = ByteCountFormatter()

struct StorageManagementView: View {
    var body: some View {
        StorageWorksView()
            .navigationTitle("管理存储空间")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StorageWorksView: View {
    @State private var works: [Work]?
    var body: some View {
        Group {
            if let works {
                List {
                    Section {
                        ForEach(works) { work in
                            NavigationLink(destination: { StorageWorkContentsView(work: work) }) {
                                HStack {
                                    WebImage(url: URL(string: work.mainCoverUrl)) { image in
                                        image
                                    } placeholder: {
                                        Rectangle()
                                            .fill(.secondary)
                                            .redacted(reason: .placeholder)
                                    }
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading) {
                                        Text(work.title)
                                            .marquee()
                                        Text(work.vas.map { $0.name }.joined(separator: "/"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .marquee()
                                    }
                                    .lineLimit(1)
                                    Spacer()
                                    Text(formatter.string(fromByteCount: DownloadManager.shared.workContentSize(work)))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { indices in
                            for (index, work) in works.enumerated() {
                                if indices.contains(index) {
                                    DownloadManager.shared.removeAllTracks(of: work)
                                }
                            }
                            self.works = DownloadManager.shared.downloadedWorks()
                        }
                    } header: {
                        HStack {
                            Text("作品")
                            Spacer()
                            Text(formatter.string(fromByteCount: DownloadManager.shared.contentTotalSize()))
                        }
                        .font(.caption)
                    }
                }
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .onAppear {
            works = DownloadManager.shared.downloadedWorks()
        }
    }
}

private struct StorageWorkContentsView: View {
    var work: Work
    @Environment(\.editMode) private var editMode
    @State private var tracks: [(TrackStructure, Int64)] = []
    var body: some View {
        List {
            Section {
                ForEach(tracks, id: \.0.hashValue) { track, size in
                    HStack {
                        Label {
                            Text(track.title)
                        } icon: {
                            switch track.type {
                            case .audio:
                                Image(systemName: "music.quarternote.3")
                            case .text:
                                Image(systemName: "text.document")
                            case .image:
                                Image(systemName: "photo")
                            case .other:
                                Image(systemName: "document")
                            default: EmptyView()
                            }
                        }
                        Spacer()
                        Text(formatter.string(fromByteCount: size))
                    }
                }
                .onDelete { indices in
                    for (index, (track, _)) in tracks.enumerated() {
                        if indices.contains(index) {
                            DownloadManager.shared.remove(track: track, of: work)
                        }
                    }
                    tracks = DownloadManager.shared.tracksWithSize(of: work)
                }
            } header: {
                HStack {
                    Text("内容")
                    Spacer()
                    Text(formatter.string(fromByteCount: DownloadManager.shared.workContentSize(work)))
                }
                .font(.caption)
            }
        }
        .navigationTitle(work.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(editMode?.wrappedValue == .active)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            tracks = DownloadManager.shared.tracksWithSize(of: work)
        }
    }
}
