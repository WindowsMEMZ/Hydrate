//
//  TrackListView.swift
//  Hydrate
//
//  Created by memz233 on 6/23/26.
//

import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect

struct TrackListView<TrailingArena: View>: View {
    var tracks: [TrackStructure]
    var work: Work
    var trailingArena: (TrackStructure) -> TrailingArena
    @State private var trackListHeight: CGFloat = 1
    @State private var trackListHeightObservation: NSKeyValueObservation?
    @State private var presentingFileTrack: TrackStructure?
    var body: some View {
        List {
            ForEach(tracks) { track in
                ContentsOfTrack(
                    track: track,
                    tracks: tracks,
                    work: work,
                    presentingFileTrack: $presentingFileTrack,
                    trailingArena: trailingArena
                )
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .frame(height: trackListHeight)
        .padding(.horizontal, -16)
        .introspect(.list, on: .iOS(.v26...)) { tableView in
            if trackListHeightObservation == nil {
                trackListHeightObservation = tableView.observe(\.contentSize) { _, _ in
                    if trackListHeight == 1 {
                        trackListHeight = tableView.contentSize.height
                    } else {
                        withAnimation(.spring(response: 0.25, dampingFraction: 1)) {
                            trackListHeight = tableView.contentSize.height
                        }
                    }
                }
            }
        }
        .sheet(item: $presentingFileTrack) { track in
            NavigationStack {
                FileTrackContentView(track: track, work: work)
            }
        }
    }
}

private struct ContentsOfTrack<TrailingArena: View>: View {
    var track: TrackStructure
    var tracks: [TrackStructure]
    var work: Work
    @Binding var presentingFileTrack: TrackStructure?
    var indentWidth: CGFloat = 0
    var trailingArena: (TrackStructure) -> TrailingArena
    @State private var isFolderExpanded = false
    var body: some View {
        if track.type == .folder, let children = track.children {
            Button {
                withAnimation {
                    isFolderExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top) {
                    Spacer(minLength: 0)
                        .frame(width: indentWidth)
                    Image(systemName: "folder")
                        .frame(width: 30)
                        .foregroundStyle(.accent)
                    Text(track.title)
                    Spacer()
                    Image(systemName: "chevron.forward.circle.fill")
                        .font(.system(size: 13))
                        .rotationEffect(.degrees(isFolderExpanded ? 90 : 0))
                }
                .foregroundStyle(Color.primary)
            }
            if isFolderExpanded {
                ForEach(children) { child in
                    ContentsOfTrack(
                        track: child,
                        tracks: tracks,
                        work: work,
                        presentingFileTrack: $presentingFileTrack,
                        indentWidth: indentWidth + 15,
                        trailingArena: trailingArena
                    )
                }
            }
        } else {
            switch track.type {
            case .audio:
                Button(action: {
                    Task {
                        let lyrics = await parseLyrics(for: track, in: tracks, of: work)
                        let playURL = DownloadManager.shared.contentURL(track: track, of: work)?.absoluteString ?? track.mediaStreamUrl!
                        AudioPlayer.shared.media = .init(
                            sourceWork: work,
                            sourceTracks: tracks,
                            currentTrack: track,
                            playURL: playURL,
                            playFileName: String(track.title.dropLast(4)),
                            lyrics: lyrics
                        )
                    }
                }, label: {
                    HStack(alignment: .top) {
                        Spacer(minLength: 0)
                            .frame(width: indentWidth)
                        Image(systemName: "music.quarternote.3")
                            .frame(width: 30)
                            .foregroundStyle(.accent)
                        Text(track.title)
                        Spacer()
                        trailingArena(track)
                    }
                    .foregroundStyle(Color.primary)
                })
            default:
                Button {
                    presentingFileTrack = track
                } label: {
                    HStack(alignment: .top) {
                        Spacer(minLength: 0)
                            .frame(width: indentWidth)
                        Image(systemName: {
                            switch track.type {
                            case .text: "text.document"
                            case .image: "photo"
                            default: "document"
                            }
                        }())
                        .frame(width: 30)
                        .foregroundStyle(.accent)
                        Text(track.title)
                        Spacer()
                        trailingArena(track)
                    }
                    .foregroundStyle(Color.primary)
                }
            }
        }
    }
}
