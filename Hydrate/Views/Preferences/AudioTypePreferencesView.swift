//
//  AudioTypePreferencesView.swift
//  Hydrate
//
//  Created by memz233 on 6/22/26.
//

import SwiftUI

struct AudioTypePreferencesView: View {
    @AppStorage("AudioTypePreferencesHaveReviewed") private var preferencesHaveReviewed = false
    @AppStorage("AudioTypePreferNoSE") private var preferNoSE = false
    @State private var audioTypes: [AudioType] = []
    var body: some View {
        List {
            Section {
                ForEach(audioTypes, id: \.self) { type in
                    Text(type.rawValue)
                }
                .onMove { src, dst in
                    audioTypes.move(fromOffsets: src, toOffset: dst)
                    savePreferences()
                }
            } header: {
                Text("文件类型")
            } footer: {
                Text("下载作品中的全部音频时，仅下载最符合偏好的一组音频。靠前的文件类型优先级更高。")
            }
            Section {
                Toggle("优先无效果音", isOn: $preferNoSE)
                    .onChange(of: preferNoSE) {
                        preferencesHaveReviewed = true
                    }
            } header: {
                Text("效果音")
            }
        }
        .environment(\.editMode, .constant(EditMode.active))
        .navigationTitle("音频类型偏好")
        .onAppear {
            if let _data = try? Data(contentsOf: URL(filePath: NSHomeDirectory() + "/Documents/AudioTypePreferences.plist")),
               let types = try? PropertyListDecoder().decode([AudioType].self, from: _data) {
                var allTypes = AudioType.allCases
                for type in types {
                    if let index = allTypes.firstIndex(of: type) {
                        audioTypes.append(type)
                        allTypes.remove(at: index)
                    }
                }
                audioTypes.append(contentsOf: allTypes)
            } else {
                audioTypes = AudioType.allCases
            }
        }
    }
    
    private func savePreferences() {
        try? PropertyListEncoder()
            .encode(audioTypes)
            .write(to: URL(filePath: NSHomeDirectory() + "/Documents/AudioTypePreferences.plist"))
        preferencesHaveReviewed = true
    }
}
