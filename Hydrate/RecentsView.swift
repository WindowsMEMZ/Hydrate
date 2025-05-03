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
    @State var recentWorks = [Work]()
    var body: some View {
        Group {
            if !recentWorks.isEmpty {
                ScrollView {
                    VStack {
                        WorkListView(works: recentWorks)
                            .workListStyle(.grid)
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
