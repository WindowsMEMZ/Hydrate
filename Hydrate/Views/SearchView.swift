//
//  SearchView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import SwiftUI
import DarockUI
import DarockFoundation
import SDWebImageSwiftUI

struct SearchView: View {
    var isSearchKeyboardFocused: FocusState<Bool>.Binding
    @Environment(\.colorScheme) var colorScheme
    @State var searchText = ""
    @State var searchTokens = [SearchToken]()
    @State var searchResults = [Work]()
    @State var currentPage = 1
    @State var totalPage = 0
    @State var isLoadingMore = false
    @State var recentSearches = [RecentSearchItem]()
    var body: some View {
        List {
            WorkListView(works: searchResults)
                .workListStyle(.plain)
                .onLastItemAppear {
                    if !isLoadingMore && currentPage <= totalPage {
                        loadMore()
                    }
                }
            if isLoadingMore {
                ProgressView()
                    .centerAligned()
            } else if searchResults.isEmpty && !recentSearches.isEmpty {
                HStack {
                    Text("最近搜索")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Button("清空", role: .destructive) {
                        recentSearches.removeAll()
                        updateSearchHistory()
                    }
                    .buttonStyle(.borderless)
                }
                .listRowSeparator(.hidden, edges: .top)
                ForEach(recentSearches) { search in
                    Button(action: {
                        searchTokens = search.tokens
                        searchText = search.text
                        performSearch(searchTokens.map { $0.searchPrompt }.joined() + searchText)
                    }, label: {
                        HStack {
                            ForEach(search.tokens) { token in
                                HStack(spacing: 4) {
                                    Image(systemName: token.representingSymbol)
                                    Text(token.id)
                                }
                                .foregroundStyle(Color.white)
                                .padding(2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(colorScheme == .dark ? Color.gray : Color(red: 142/255, green: 142/255, blue: 147/255)))
                            }
                            Text(search.text)
                        }
                    })
                }
                .onDelete { indexs in
                    recentSearches.remove(atOffsets: indexs)
                    updateSearchHistory()
                }
            }
            Spacer()
                .frame(height: 50)
                .listRowSeparator(.hidden, edges: .bottom)
        }
        .listStyle(.plain)
        .searchable(text: $searchText, tokens: $searchTokens, prompt: "音声、声优、标签，以及更多") { token in
            Label(token.id, systemImage: token.representingSymbol)
        }
        .searchSuggestions {
            if !searchText.isEmpty {
                Label("搜索包含“\(searchText)”标签的作品", systemImage: "tag").searchCompletion(SearchToken.tag(searchText))
                Label("搜索“\(searchText)”社团的作品", systemImage: "person.3").searchCompletion(SearchToken.circle(searchText))
                Label("搜索“\(searchText)”声优的作品", systemImage: "person").searchCompletion(SearchToken.va(searchText))
                if searchText.hasSuffix("m") || searchText.hasSuffix("h") {
                    Label("搜索时长大于“\(searchText)”的作品", systemImage: "clock").searchCompletion(SearchToken.duration(searchText))
                    Label("搜索时长小于“\(searchText)”的作品", systemImage: "clock.badge.questionmark").searchCompletion(SearchToken.antiDuration(searchText))
                }
                if let _rate = Double(searchText), _rate >= 0 && _rate <= 5 {
                    Label("搜索评分高于\(searchText)的作品", systemImage: "star.leadinghalf.filled").searchCompletion(SearchToken.rate(searchText))
                }
                if Int(searchText) != nil {
                    Label("搜索价格高于\(searchText)的作品", systemImage: "dollarsign").searchCompletion(SearchToken.price(searchText))
                    Label("搜索销量大于\(searchText)的作品", systemImage: "checkmark.rectangle.stack").searchCompletion(SearchToken.sell(searchText))
                }
                if ["general", "r15", "adult"].contains(searchText) {
                    Label("搜索年龄分级为“\(searchText)”的作品", systemImage: "figure.and.child.holdinghands").searchCompletion(SearchToken.age(searchText))
                    Label("排除年龄分级为“\(searchText)”的作品", systemImage: "figure.child.and.lock").searchCompletion(SearchToken.antiAge(searchText))
                }
                Label("搜索语言为“\(searchText)”的作品", systemImage: "globe").searchCompletion(SearchToken.lang(searchText))
                Label("排除包含“\(searchText)”标签的作品", systemImage: "tag.slash").searchCompletion(SearchToken.antiTag(searchText))
                Label("排除“\(searchText)”社团的作品", systemImage: "person.2.slash").searchCompletion(SearchToken.antiCircle(searchText))
                Label("排除“\(searchText)”声优的作品", systemImage: "person.slash").searchCompletion(SearchToken.antiVA(searchText))
                Label("排除语言为“\(searchText)”的作品", systemImage: "globe.badge.chevron.backward").searchCompletion(SearchToken.antiLang(searchText))
            }
        }
        .searchFocused(isSearchKeyboardFocused)
        .onSubmit(of: .search) {
            performSearch(searchTokens.map { $0.searchPrompt }.joined() + searchText)
            recentSearchInsert(.init(tokens: searchTokens, text: searchText))
            updateSearchHistory()
        }
        .navigationTitle("搜索")
        .onAppear {
            if let jsonString = try? String(contentsOfFile: NSHomeDirectory() + "/Documents/RecentSearches.json", encoding: .utf8) {
                recentSearches = getJsonData([RecentSearchItem].self, from: jsonString) ?? []
            }
        }
        .onChange(of: searchText) {
            if searchText.isEmpty && searchTokens.isEmpty {
                searchResults.removeAll()
            }
        }
        .onChange(of: searchTokens) {
            if searchText.isEmpty && searchTokens.isEmpty {
                searchResults.removeAll()
            }
        }
        .onReceive(performSearchSubject) { text in
            performSearch(text)
            searchText = text
            recentSearchInsert(.init(tokens: [], text: searchText))
            updateSearchHistory()
        }
    }
    
    func performSearch(_ text: String) {
        isLoadingMore = true
        currentPage = 1
        totalPage = 0
        requestJSON("https://api.asmr.one/api/search/\(text.urlEncoded())?order=create_date&sort=desc&page=1&subtitle=0&includeTranslationWorks=true") { respJson, isSuccess in
            if isSuccess {
                searchResults = getJsonData([Work].self, from: respJson["works"].rawString()!) ?? []
                totalPage = (respJson["pagination"]["totalCount"].int ?? 1) / (respJson["pagination"]["pageSize"].int ?? 1) + 1
                currentPage++
            }
            isLoadingMore = false
        }
    }
    func loadMore() {
        isLoadingMore = true
        requestJSON("https://api.asmr.one/api/search/\((searchTokens.map { $0.searchPrompt }.joined() + searchText).urlEncoded())?order=create_date&sort=desc&page=\(currentPage)&subtitle=0&includeTranslationWorks=true") { respJson, isSuccess in
            if isSuccess {
                searchResults += getJsonData([Work].self, from: respJson["works"].rawString()!) ?? []
                totalPage = (respJson["pagination"]["totalCount"].int ?? 1) / (respJson["pagination"]["pageSize"].int ?? 1) + 1
                currentPage++
            }
            isLoadingMore = false
        }
    }
    func recentSearchInsert(_ item: RecentSearchItem) {
        if !recentSearches.contains(item) {
            recentSearches.insert(item, at: 0)
        } else {
            recentSearches.move(fromOffsets: [recentSearches.firstIndex(of: item)!], toOffset: 0)
        }
    }
    func updateSearchHistory() {
        if let jsonString = jsonString(from: recentSearches) {
            try? jsonString.write(toFile: NSHomeDirectory() + "/Documents/RecentSearches.json", atomically: true, encoding: .utf8)
        }
    }
}
