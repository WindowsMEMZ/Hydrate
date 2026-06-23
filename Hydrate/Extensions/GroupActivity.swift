//
//  GroupActivity.swift
//  Hydrate
//
//  Created by memz233 on 6/23/26.
//

import SwiftUI
import Foundation
import GroupActivities
import CoreTransferable

extension NowPlayingInfo: GroupActivity {
    var metadata: GroupActivityMetadata {
        var result = GroupActivityMetadata()
        result.type = .listenTogether
        result.title = sourceWork.title
        result.subtitle = playFileName
        result.fallbackURL = URL(
            string: "https://www.asmr.one/work/\(sourceWork.source_id)"
        )
        return result
    }
}
extension NowPlayingInfo: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { transferable in
            URL(
                string: "https://www.asmr.one/work/\(transferable.sourceWork.source_id)"
            )!
        }
//        CodableRepresentation(
//            contentType: .init(
//                identifier: "com.memz233.Hydrate.NowPlayingInfo",
//                allowUndeclared: true
//            )!
//        )
    }
    
    var sharePreview: SharePreview<_TransferableAsyncImage, Never> {
        SharePreview(
            sourceWork.title,
            image: .init(url: URL(string: sourceWork.mainCoverUrl)!)
        )
    }
}

struct _TransferableAsyncImage: Transferable {
    @diagnose(DeprecatedDeclaration, as: ignored)
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { image in
            let data = try await URLSession.shared.data(from: image.url).0
            return Image(uiImage: .init(data: data)!)
        }
    }
    
    var url: URL
}
