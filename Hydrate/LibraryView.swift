//
//  LibraryView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/1.
//

import SwiftUI
import CachedAsyncImage
import DarockFoundation

struct LibraryView: View {
    @Namespace var favoriteNavigationNamespace
    @AppStorage("AccountToken") var accountToken = ""
    @State var favoriteWorks = [Work]()
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
                                        .scrollTargetLayout()
                                    }
                                }
                            }
                            .scrollIndicators(.never)
                            .scrollTargetBehavior(.viewAligned)
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
                Text("请先登录")
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
