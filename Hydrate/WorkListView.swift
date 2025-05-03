//
//  WorkListView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/3.
//

import SwiftUI
import DarockUI
import SDWebImageSwiftUI

struct WorkListView: View {
    var works: [Work]
    private var style: WorkListViewStyle = .horizontalScroll
    private var onLastItemAppear: (() -> Void)?
    @Namespace private var navigationNamespace
    
    init(works: [Work]) {
        self.works = works
        self.style = .horizontalScroll
    }
    
    var body: some View {
        switch style {
        case .horizontalScroll:
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    if !works.isEmpty {
                        ForEach(works) { work in
                            NavigationLink {
                                WorkDetailView(id: work.id)
                                    .navigationTransition(.zoom(sourceID: work.id, in: navigationNamespace))
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
                                    .matchedTransitionSource(id: work.id, in: navigationNamespace)
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
                            .onAppear {
                                if work.id == works.last?.id {
                                    onLastItemAppear?()
                                }
                            }
                        }
                    } else {
                        ForEach(0...5, id: \.self) { _ in
                            VStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray)
                                    .frame(width: 150, height: 150)
                                    .cornerRadius(7)
                                    .redacted(reason: .placeholder)
                                Text(verbatim: "Title")
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                    .foregroundStyle(Color.primary)
                                    .redacted(reason: .placeholder)
                                Text(verbatim: "Placeholder")
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .foregroundStyle(.gray)
                                    .redacted(reason: .placeholder)
                            }
                            .frame(width: 160)
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
        case .grid:
            LazyVGrid(columns: [.init(), .init()], spacing: 6) {
                if !works.isEmpty {
                    ForEach(works) { work in
                        NavigationLink {
                            WorkDetailView(id: work.id)
                                .navigationTransition(.zoom(sourceID: work.id, in: navigationNamespace))
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
                                .matchedTransitionSource(id: work.id, in: navigationNamespace)
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
                            if work.id == works.last?.id {
                                onLastItemAppear?()
                            }
                        }
                    }
                } else {
                    ForEach(0...9, id: \.self) { _ in
                        VStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray)
                                .frame(width: UIScreen.main.bounds.width / 2 - 24, height: UIScreen.main.bounds.width / 2 - 24)
                                .cornerRadius(7)
                                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.gray.opacity(0.6)))
                                .redacted(reason: .placeholder)
                            Text(verbatim: "Title")
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .foregroundStyle(Color.primary)
                                .redacted(reason: .placeholder)
                            Text(verbatim: "Placeholder")
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .foregroundStyle(.gray)
                                .redacted(reason: .placeholder)
                        }
                    }
                }
            }
            .centerAligned()
            .padding(.horizontal, -10)
        case .plain:
            ForEach(works) { work in
                NavigationLink { WorkDetailView(id: work.id) } label: {
                    HStack {
                        WebImage(url: URL(string: work.mainCoverUrl)) { image in
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
                            Text(work.tags.map(\.name).joined(separator: "·"))
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
                    if work.id == works.last?.id {
                        onLastItemAppear?()
                    }
                }
            }
        }
    }
    
    enum WorkListViewStyle {
        case horizontalScroll
        case grid
        case plain
    }
}
extension WorkListView {
    func workListStyle(_ style: WorkListViewStyle) -> Self {
        var mutableCopy = self
        mutableCopy.style = style
        return mutableCopy
    }
    func onLastItemAppear(perform action: (() -> Void)?) -> Self {
        var mutableCopy = self
        mutableCopy.onLastItemAppear = action
        return mutableCopy
    }
}
