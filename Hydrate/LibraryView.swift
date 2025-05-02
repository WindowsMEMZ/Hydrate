//
//  LibraryView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/1.
//

import SwiftUI
import DarockUI
import CachedAsyncImage
import DarockFoundation

struct LibraryView: View {
    @Namespace var favoriteNavigationNamespace
    @Namespace var downloadedNavigationNamespace
    @AppStorage("AccountToken") var accountToken = ""
    @State var favoriteWorks = [Work]()
    @State var downloadedWorks = [Work]()
    var body: some View {
        Group {
            if !accountToken.isEmpty {
                ScrollView {
                    VStack(alignment: .leading) {
                        if !favoriteWorks.isEmpty {
                            NavigationLink(destination: { FavoritesView() }, label: {
                                HStack(spacing: 5) {
                                    Text("我的收藏")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(Color.primary)
                                    Image(systemName: "chevron.forward")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.gray)
                                }
                            })
                            .buttonStyle(.borderless)
                            ScrollView(.horizontal) {
                                HStack(spacing: 0) {
                                    ForEach(favoriteWorks) { work in
                                        NavigationLink {
                                            WorkDetailView(id: work.id)
                                                .navigationTransition(.zoom(sourceID: work.id, in: favoriteNavigationNamespace))
                                        } label: {
                                            VStack(alignment: .leading) {
                                                CachedAsyncImage(url: URL(string: work.mainCoverUrl)) { image in
                                                    image.resizable()
                                                } placeholder: {
                                                    Rectangle()
                                                        .fill(Color.gray)
                                                        .redacted(reason: .placeholder)
                                                }
                                                .scaledToFill()
                                                .frame(width: 150, height: 150)
                                                .clipped()
                                                .cornerRadius(7)
                                                .matchedTransitionSource(id: work.id, in: favoriteNavigationNamespace)
                                                Text(work.title)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .lineLimit(1)
                                                    .foregroundStyle(Color.primary)
                                                Text(work.vas.map { $0.name }.joined(separator: "/"))
                                                    .font(.system(size: 12))
                                                    .lineLimit(1)
                                                    .foregroundStyle(.gray)
                                            }
                                            .frame(width: 160)
                                        }
                                        .contextMenu {
                                            work.contextActions
                                        } preview: {
                                            work.previewView
                                        }
                                    }
                                }
                                .scrollTargetLayout()
                                .scrollTransition { content, _ in
                                    content.offset(x: 14)
                                }
                            }
                            .scrollIndicators(.never)
                            .scrollTargetBehavior(.viewAligned)
                            .padding(.horizontal, -16)
                        }
                        if !downloadedWorks.isEmpty {
                            Text("已下载")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.primary)
                            LazyVGrid(columns: [.init(), .init()], spacing: 6) {
                                ForEach(downloadedWorks) { work in
                                    NavigationLink {
                                        WorkDetailView(id: work.id)
                                            .navigationTransition(.zoom(sourceID: work.id, in: downloadedNavigationNamespace))
                                    } label: {
                                        VStack(alignment: .leading) {
                                            CachedAsyncImage(url: URL(string: work.mainCoverUrl)) { image in
                                                image.resizable()
                                            } placeholder: {
                                                Rectangle()
                                                    .fill(Color.gray)
                                                    .redacted(reason: .placeholder)
                                            }
                                            .scaledToFill()
                                            .frame(width: UIScreen.main.bounds.width / 2 - 24, height: UIScreen.main.bounds.width / 2 - 24)
                                            .clipped()
                                            .cornerRadius(7)
                                            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.gray.opacity(0.6)))
                                            .matchedTransitionSource(id: work.id, in: downloadedNavigationNamespace)
                                            Text(work.title)
                                                .font(.system(size: 12, weight: .medium))
                                                .lineLimit(1)
                                                .foregroundStyle(Color.primary)
                                            Text(work.vas.map { $0.name }.joined(separator: "/"))
                                                .font(.system(size: 12))
                                                .lineLimit(1)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                    .contextMenu {
                                        work.contextActions
                                    } preview: {
                                        work.previewView
                                    }
                                }
                            }
                            .centerAligned()
                            .padding(.horizontal, -10)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    refresh()
                }
                .onAppear {
                    refresh()
                }
            } else {
                ContentUnavailableView("尚未登录", systemImage: "person.crop.circle.badge.questionmark.fill", description: Text("在“账户”页面登录以访问资料库"))
            }
        }
        .navigationTitle("资料库")
    }
    
    func refresh() {
        requestJSON("https://api.asmr.one/api/review?order=updated_at&sort=desc&page=1", headers: globalRequestHeaders) { respJson, isSuccess in
            if isSuccess {
                favoriteWorks = getJsonData([Work].self, from: respJson["works"].rawString()!) ?? []
            }
        }
        downloadedWorks = DownloadManager.shared.downloadedWorks()
    }
    
    struct FavoritesView: View {
        @AppStorage("AccountToken") var accountToken = ""
        @State var favoriteWorks = [Work]()
        @State var currentPage = 1
        @State var totalPage = 0
        @State var isLoadingMore = false
        var body: some View {
            List {
                ForEach(favoriteWorks) { work in
                    NavigationLink { WorkDetailView(id: work.id) } label: {
                        HStack {
                            CachedAsyncImage(url: URL(string: work.mainCoverUrl)) { image in
                                image.resizable()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray)
                                    .redacted(reason: .placeholder)
                            }
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(6)
                            VStack(alignment: .leading) {
                                Text(work.title)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .foregroundStyle(Color.primary)
                                Text(work.vas.map { $0.name }.joined(separator: "/"))
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    .contextMenu {
                        work.contextActions
                    } preview: {
                        work.previewView
                    }
                    .onAppear {
                        if work.id == favoriteWorks.last?.id && !isLoadingMore && currentPage <= totalPage {
                            loadMore()
                        }
                    }
                }
                if isLoadingMore {
                    ProgressView()
                        .centerAligned()
                }
            }
            .listStyle(.plain)
            .navigationTitle("我的收藏")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                refresh()
            }
            .onAppear {
                refresh()
            }
        }
        
        func refresh() {
            currentPage = 1
            totalPage = 0
            requestJSON("https://api.asmr.one/api/review?order=updated_at&sort=desc&page=1", headers: globalRequestHeaders) { respJson, isSuccess in
                if isSuccess {
                    favoriteWorks = getJsonData([Work].self, from: respJson["works"].rawString()!) ?? []
                    totalPage = (respJson["pagination"]["totalCount"].int ?? 1) / (respJson["pagination"]["pageSize"].int ?? 1) + 1
                    currentPage++
                }
            }
        }
        func loadMore() {
            isLoadingMore = true
            requestJSON("https://api.asmr.one/api/review?order=updated_at&sort=desc&page=\(currentPage)") { respJson, isSuccess in
                if isSuccess {
                    favoriteWorks += getJsonData([Work].self, from: respJson["works"].rawString()!) ?? []
                    totalPage = (respJson["pagination"]["totalCount"].int ?? 1) / (respJson["pagination"]["pageSize"].int ?? 1) + 1
                    currentPage++
                }
                isLoadingMore = false
            }
        }
    }
}
