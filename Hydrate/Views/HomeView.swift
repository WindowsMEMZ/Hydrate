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
                if !accountToken.isEmpty {
                    Text("专属精选推荐")
                        .font(.system(size: 22, weight: .bold))
                    WorkListView(works: userSuggestionWorks)
                }
                Text("热门")
                    .font(.system(size: 22, weight: .bold))
                WorkListView(works: popularWorks)
                Text("所有作品")
                    .font(.system(size: 22, weight: .bold))
                WorkListView(works: allWorks)
                    .workListStyle(.grid)
                    .onLastItemAppear {
                        if !isLoadingMore && currentPage <= totalPage {
                            loadMore()
                        }
                    }
                if isLoadingMore {
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
