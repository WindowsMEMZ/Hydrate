//
//  WorkDetailView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import SwiftUI
import DarockUI
import NotifKit
import Alamofire
import CachedAsyncImage
import DarockFoundation
@_spi(Advanced) import SwiftUIIntrospect

struct WorkDetailView: View {
    var id: Int
    @AppStorage("AccountToken") var accountToken = ""
    @State var work: Work?
    @State var tracks: [TrackStructure]?
    @State var trackListHeightObservation: NSKeyValueObservation?
    @State var trackListHeight: CGFloat = 1
    @State var textFileURLPresentation: String?
    @State var textFilePresentationContent: String?
    @State var imageFileURLPresentation: String?
    @State var isRemoveFromFavoriteConfirmationPresented = false
    var body: some View {
        ScrollView {
            if let work {
                VStack {
                    CachedAsyncImage(url: URL(string: work.mainCoverUrl)) { image in
                        image.resizable()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray)
                            .redacted(reason: .placeholder)
                    }
                    .scaledToFill()
                    .frame(width: 220, height: 220)
                    .clipped()
                    .cornerRadius(8)
                    .shadow(radius: 15, x: 3, y: 3)
                    Text(work.title)
                        .font(.system(size: 16, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding([.top, .horizontal])
                    if work.vas.count == 1 {
                        Button(action: {
                            performSearchSubject.send("$va:\(work.vas[0].name)$")
                        }, label: {
                            Text(work.vas[0].name)
                                .font(.system(size: 16))
                        })
                    } else if work.vas.count > 1 {
                        Menu(work.vas.map { $0.name }.joined(separator: "/")) {
                            ForEach(work.vas, id: \.self) { va in
                                Button(action: {
                                    performSearchSubject.send("$va:\(va.name)$")
                                }, label: {
                                    Text(va.name)
                                        .font(.system(size: 16))
                                })
                            }
                        }
                    }
                    if let tracks {
                        List(tracks, id: \.self, children: \.children) { track in
                            switch track.type {
                            case .folder:
                                Label(track.title, systemImage: "folder")
                            case .audio:
                                Button(action: {
                                    Task {
                                        var lyrics: [ClosedRange<Double>: String]?
                                        let allFiles = tracks.flattened
                                        for file in allFiles {
                                            if file.title == "\(track.title).vtt" {
                                                let result = await requestString(file.mediaStreamUrl!)
                                                if case let .success(respStr) = result {
                                                    lyrics = parseVTT(respStr)
                                                }
                                                break
                                            } else if file.title == "\(track.title).lrc" {
                                                let result = await requestString(file.mediaStreamUrl!)
                                                if case let .success(respStr) = result {
                                                    lyrics = parseLRC(respStr)
                                                }
                                                break
                                            }
                                        }
                                        nowPlayingMedia.send(.init(sourceWork: work, playURL: track.mediaStreamUrl!, playFileName: String(track.title.dropLast(4)), lyrics: lyrics))
                                    }
                                }, label: {
                                    Label(track.title, systemImage: "music.quarternote.3")
                                })
                            case .text:
                                Button(action: {
                                    textFileURLPresentation = track.mediaStreamUrl!
                                }, label: {
                                    Label(track.title, systemImage: "text.document")
                                })
                            case .image:
                                Button(action: {
                                    imageFileURLPresentation = track.mediaStreamUrl!
                                }, label: {
                                    Label(track.title, systemImage: "photo")
                                })
                            case .other:
                                if let url = track.mediaStreamUrl {
                                    Link(destination: URL(string: url)!) {
                                        Label(track.title, systemImage: "document")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollDisabled(true)
                        .frame(height: trackListHeight)
                        .animation(.easeOut(duration: 0.2), value: trackListHeight)
                        .introspect(.list, on: .iOS(.v18...)) { tableView in
                            trackListHeightObservation = tableView.observe(\.contentSize) { _, _ in
                                trackListHeight = tableView.contentSize.height
                            }
                        }
                    } else {
                        ProgressView()
                    }
                }
                .padding()
                .padding(.bottom, 50)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .toolbar {
            if let work {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Section {
                            if !accountToken.isEmpty {
                                if work.userRating != nil {
                                    Button("从收藏中移除", systemImage: "trash", role: .destructive) {
                                        isRemoveFromFavoriteConfirmationPresented = true
                                    }
                                } else {
                                    Button("收藏", systemImage: "star") {
                                        requestJSON("https://api.asmr.one/api/review", method: .put, parameters: ["work_id": work.id, "rating": 5, "review_text": nil, "progress": nil], encoding: JSONEncoding.default, headers: globalRequestHeaders) { _, isSuccess in
                                            if isSuccess {
                                                NKTipper.automaticStyle.present(text: "已添加到收藏", symbol: "checkmark.circle.fill")
                                                loadWorkInfo()
                                            } else {
                                                NKTipper.automaticStyle.present(text: "收藏时出错", symbol: "xmark.circle.fill")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Section {
                            Link(destination: URL(string: "https://www.asmr.one/work/\(work.source_id)")!) {
                                Label("在浏览器中打开", systemImage: "safari")
                            }
                            ShareLink("分享作品...", item: URL(string: "https://www.asmr.one/work/\(work.source_id)")!)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(5)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
            }
        }
        .confirmationDialog("", isPresented: $isRemoveFromFavoriteConfirmationPresented) {
            Button("移除", role: .destructive) {
                requestJSON("https://api.asmr.one/api/review?work_id=\(work!.id)", method: .delete, headers: globalRequestHeaders) { _, isSuccess in
                    if isSuccess {
                        loadWorkInfo()
                    } else {
                        NKTipper.automaticStyle.present(text: "移除时出错", symbol: "xmark.circle.fill")
                    }
                }
            }
        } message: {
            Text("确定将此作品从收藏中移除吗？")
        }
        .sheet(item: $textFileURLPresentation) { url in
            NavigationStack {
                Group {
                    if let text = textFilePresentationContent {
                        TextEditor(text: .constant(text))
                            .padding()
                    } else {
                        ProgressView()
                            .controlSize(.large)
                    }
                }
                .navigationTitle("文本")
                .navigationBarTitleDisplayMode(.inline)
                .withDismissButton {
                    textFileURLPresentation = nil
                }
            }
            .task {
                let result = await requestString(url)
                if case let .success(respStr) = result {
                    textFilePresentationContent = respStr
                }
            }
            .onDisappear {
                textFilePresentationContent = nil
            }
        }
        .sheet(item: $imageFileURLPresentation) { url in
            NavigationStack {
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                        .controlSize(.large)
                }
                .scaledToFit()
                .navigationTitle("图像")
                .navigationBarTitleDisplayMode(.inline)
                .withDismissButton({
                    textFileURLPresentation = nil
                }, placement: .leading)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            DispatchQueue(label: "com.memz233.Hydrate.SaveImageToPhotos", qos: .userInitiated).async {
                                if let _data = try? Data(contentsOf: URL(string: url)!),
                                   let image = UIImage(data: _data) {
                                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                                    NKTipper.automaticStyle.present(text: "已存储", symbol: "checkmark.circle.fill")
                                }
                            }
                        }, label: {
                            Image(systemName: "square.and.arrow.down")
                        })
                    }
                }
            }
        }
        .onAppear {
            loadWorkInfo()
            loadTrackInfo()
        }
    }
    
    func loadWorkInfo() {
        requestString("https://api.asmr.one/api/work/\(id)", headers: globalRequestHeaders) { respStr, isSuccess in
            if isSuccess {
                work = getJsonData(Work.self, from: respStr) ?? nil
            }
        }
    }
    func loadTrackInfo() {
        requestString("https://api.asmr.one/api/tracks/\(id)?v=1", headers: globalRequestHeaders) { respStr, isSuccess in
            if isSuccess {
                tracks = getJsonData([TrackStructure].self, from: respStr) ?? nil
            }
        }
    }
}
