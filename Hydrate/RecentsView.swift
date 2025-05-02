//
//  RecentsView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/2.
//

import SwiftUI
import DarockUI
import SDWebImageSwiftUI

struct RecentsView: View {
    @Namespace var recentNavigationNamespace
    @State var recentWorks = [Work]()
    var body: some View {
        Group {
            if !recentWorks.isEmpty {
                ScrollView {
                    VStack {
                        LazyVGrid(columns: [.init(), .init()], spacing: 6) {
                            ForEach(recentWorks) { work in
                                NavigationLink {
                                    WorkDetailView(id: work.id)
                                        .navigationTransition(.zoom(sourceID: work.id, in: recentNavigationNamespace))
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
                                        .matchedTransitionSource(id: work.id, in: recentNavigationNamespace)
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
                    .padding()
                    .padding(.bottom, 60)
                }
            } else {
                ContentUnavailableView("无最近浏览项目", systemImage: "clock.fill")
            }
        }
        .navigationTitle("最近浏览")
        .onAppear {
            if let _recentData = try? Data(contentsOf: URL(filePath: NSHomeDirectory() + "/Documents/Recents.plist")),
               let recents = try? PropertyListDecoder().decode([Work].self, from: _recentData) {
                recentWorks = recents
            }
        }
    }
}
