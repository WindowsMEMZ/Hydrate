//
//  HomeView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import SwiftUI
import DarockUI
import Alamofire
import DarockFoundation
import SDWebImageSwiftUI

struct HomeView: View {
    @Namespace var userSuggestionNavigationNamespace
    @Namespace var popularNavigationNamespace
    @Namespace var allWorkNavigationNamespace
    @AppStorage("AccountToken") var accountToken = ""
    @State var userSuggestionWorks = [Work]()
    @State var popularWorks = [Work]()
    @State var allWorks = [Work]()
    @State var currentPage = 1
    @State var totalPage = 0
    @State var isLoadingMore = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if !userSuggestionWorks.isEmpty {
                    Text("专属精选推荐")
                        .font(.system(size: 22, weight: .bold))
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(userSuggestionWorks) { work in
                                NavigationLink {
                                    WorkDetailView(id: work.id)
                                        .navigationTransition(.zoom(sourceID: work.id, in: userSuggestionNavigationNamespace))
                                } label: {
                                    VStack(alignment: .leading) {
                                        WebImage(url: URL(string: work.mainCoverUrl)) { image in
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
                                        .matchedTransitionSource(id: work.id, in: userSuggestionNavigationNamespace)
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
                    .padding(.bottom, 2)
                    .padding(.horizontal, -16)
                }
                Text("热门")
                    .font(.system(size: 22, weight: .bold))
                if !popularWorks.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(popularWorks) { work in
                                NavigationLink {
                                    WorkDetailView(id: work.id)
                                        .navigationTransition(.zoom(sourceID: work.id, in: popularNavigationNamespace))
                                } label: {
                                    VStack(alignment: .leading) {
                                        WebImage(url: URL(string: work.mainCoverUrl)) { image in
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
                                        .matchedTransitionSource(id: work.id, in: popularNavigationNamespace)
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
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .centerAligned()
                }
                Text("所有作品")
                    .font(.system(size: 22, weight: .bold))
                if !allWorks.isEmpty {
                    LazyVGrid(columns: [.init(), .init()], spacing: 6) {
                        ForEach(allWorks) { work in
                            NavigationLink {
                                WorkDetailView(id: work.id)
                                    .navigationTransition(.zoom(sourceID: work.id, in: allWorkNavigationNamespace))
                            } label: {
                                VStack(alignment: .leading) {
                                    WebImage(url: URL(string: work.mainCoverUrl)) { image in
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
                                    .matchedTransitionSource(id: work.id, in: allWorkNavigationNamespace)
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
                            .onAppear {
                                if work.id == allWorks.last?.id && !isLoadingMore && currentPage <= totalPage {
                                    loadMore()
                                }
                            }
                        }
                    }
                    .centerAligned()
                    .padding(.horizontal, -10)
                    if isLoadingMore {
                        ProgressView()
                            .controlSize(.large)
                            .centerAligned()
                    }
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .centerAligned()
                }
                Spacer()
                    .frame(height: 20)
            }
            .padding()
        }
        .navigationTitle("主页")
        .refreshable {
            refresh()
        }
        .onAppear {
            refresh()
        }
    }
    
    func refresh() {
        if !accountToken.isEmpty {
            requestJSON("https://api.asmr.one/api/recommender/recommend-for-user", method: .post, parameters: ["keyword": " ", "page": 1, "subtitle": 0, "localSubtitledWorks": [], "withPlaylistStatus": []], encoding: JSONEncoding.default, headers: globalRequestHeaders) { respJson, isSuccess in
                if isSuccess {
                    userSuggestionWorks = getJsonData([Work].self, from: respJson["works"].rawString()!) ?? []
                }
            }
        }
        requestJSON("https://api.asmr.one/api/recommender/popular", method: .post, parameters: ["keyword": " ", "page": 1, "subtitle": 0, "localSubtitledWorks": [], "withPlaylistStatus": []], encoding: JSONEncoding.default) { respJson, isSuccess in
            if isSuccess {
                popularWorks = getJsonData([Work].self, from: respJson["works"].rawString()!) ?? []
            }
        }
        currentPage = 1
        totalPage = 0
        requestJSON("https://api.asmr.one/api/works?order=create_date&sort=desc&page=1&subtitle=0") { respJson, isSuccess in
            if isSuccess {
                allWorks = getJsonData([Work].self, from: respJson["works"].rawString()!) ?? []
                totalPage = (respJson["pagination"]["totalCount"].int ?? 1) / (respJson["pagination"]["pageSize"].int ?? 1) + 1
                currentPage++
            }
        }
    }
    func loadMore() {
        isLoadingMore = true
        requestJSON("https://api.asmr.one/api/works?order=create_date&sort=desc&page=\(currentPage)&subtitle=0") { respJson, isSuccess in
            if isSuccess {
                allWorks += getJsonData([Work].self, from: respJson["works"].rawString()!) ?? []
                totalPage = (respJson["pagination"]["totalCount"].int ?? 1) / (respJson["pagination"]["pageSize"].int ?? 1) + 1
                currentPage++
            }
            isLoadingMore = false
        }
    }
}
