//
//  Tips.swift
//  Hydrate
//
//  Created by memz233 on 6/19/26.
//

import TipKit
import SwiftUI

struct TrackDownloadingTip: Tip {
    var title: Text {
        Text("正在下载内容")
    }
    
    var message: Text? {
        Text("""
        你可以正常使用 Hydrate 或是其他 App，下载会在后台完成。\
        连接到蜂窝网络时，下载将自动暂停直到恢复无线局域网连接。
        """)
    }
    
    var image: Image? {
        Image(systemName: "arrow.down.circle")
    }
    
    var options: [any TipOption] {
        MaxDisplayCount(1)
    }
}
