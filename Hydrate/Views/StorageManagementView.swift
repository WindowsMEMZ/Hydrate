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
                                    Text(work.vas.map { $0.name }.joined(separator: "/"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .lineLimit(1)
                                Spacer()
                                Text(formatter.string(fromByteCount: DownloadManager.shared.workContentSize(work)))
                                    .foregroundStyle(.secondary)
                            }
                        }
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
                .onAppear {
                    works = DownloadManager.shared.downloadedWorks()
                }
        }
    }
}

private struct StorageWorkContentsView: View {
    var work: Work
    @Environment(\.editMode) private var editMode
    var body: some View {
        List {
            Section {
                let tracks = DownloadManager.shared.tracksWithSize(of: work)
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
                    let tracks = tracks.enumerated()
                        .filter { indices.contains($0) && $1 == $1 }
                        .map { $0.element.0 }
                    for track in tracks {
                        DownloadManager.shared.remove(track: track, of: work)
                    }
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
    }
}
