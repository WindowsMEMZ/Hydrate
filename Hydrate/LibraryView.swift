//
//  LibraryView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/1.
//

import SwiftUI
import DarockUI
import DarockFoundation
import SDWebImageSwiftUI

struct LibraryView: View {
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
                            WorkListView(works: favoriteWorks)
                        }
                        if !downloadedWorks.isEmpty {
                            Text("已下载")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.primary)
                            WorkListView(works: downloadedWorks)
                                .workListStyle(.grid)
                        }
                    }
                    .padding()
                    .padding(.bottom, 60)
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
                WorkListView(works: favoriteWorks)
                    .workListStyle(.plain)
                    .onLastItemAppear {
                        if !isLoadingMore && currentPage <= totalPage {
                            loadMore()
                        }
                    }
                if isLoadingMore {
                    ProgressView()
                        .centerAligned()
                }
                Spacer()
                    .frame(height: 50)
                    .listRowSeparator(.hidden, edges: .bottom)
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
