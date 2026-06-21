//
//  AccountView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/1.
//

import SwiftUI
import DarockUI
import NotifKit
import Alamofire
import Translation
import DarockFoundation

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("AccountToken") private var accountToken = ""
    @AppStorage("CachedUserName") private var cachedUserName = ""
    @AppStorage("RecentWorkPreservingCount") private var recentWorkPreservingCount = 10
    @AppStorage("AutoTranscribeEnabled") private var autoTranscribeEnabled = false
    @AppStorage("TranscriptionTranslationEnabled") private var transcriptionTranslationEnabled = false
    @AppStorage("TranscriptionTranslationTarget") private var transcriptionTranslationTarget = ""
    var body: some View {
        NavigationStack {
            List {
                if !accountToken.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 40))
                                .foregroundStyle(.accent)
                            Text(cachedUserName)
                        }
                        Button("退出登录", role: .destructive) {
                            accountToken = ""
                            cachedUserName = ""
                        }
                    }
                } else {
                    NavigationLink(destination: { LoginView() }, label: {
                        Label("登录", systemImage: "key.fill")
                    })
                    NavigationLink(destination: { RegisterView() }, label: {
                        Label("注册", systemImage: "person.badge.plus")
                    })
                }
                Section {
                    Picker("保留最近浏览", selection: $recentWorkPreservingCount) {
                        Text("10 条").tag(10)
                        Text("20 条").tag(20)
                        Text("50 条").tag(50)
                        Text("100 条").tag(100)
                    }
                } header: {
                    Text("资料库")
                }
                Section {
                    Toggle("转写未提供字幕文件的音声", isOn: $autoTranscribeEnabled)
                        .onChange(of: autoTranscribeEnabled) {
                            if autoTranscribeEnabled {
                                Task {
                                    print(try? await LyricsTranscriber.ensureAssets())
                                    print("Success")
                                }
                            }
                        }
                    Toggle(isOn: $transcriptionTranslationEnabled) {
                        Text("自动翻译字幕内容")
                            .background {
                                if transcriptionTranslationEnabled {
                                    Color.clear
                                        .translationTask(source: .init(identifier: "ja"), target: LyricTranslation._language(fromTarget: transcriptionTranslationTarget)) { session in
                                            Task {
                                                try? await session.translate("こんにちは")
                                            }
                                        }
                                }
                            }
                    }
                    if transcriptionTranslationEnabled {
                        Picker("翻译目标语言", selection: $transcriptionTranslationTarget) {
                            Text("自动").tag("")
                            Text("English").tag("en")
                            Text("简体中文").tag("zh-Hans")
                        }
                    }
                } header: {
                    Text("字幕")
                }
                Section {
                    NavigationLink(destination: { StorageManagementView() }) {
                        HStack {
                            Text("管理存储空间")
                            Spacer()
                            Text(ByteCountFormatter().string(fromByteCount: DownloadManager.shared.contentTotalSize()))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("下载")
                }
                Section {
                    NavigationLink(destination: { AboutView() }, label: {
                        Label("关于 App", systemImage: "info.circle.fill")
                    })
                }
            }
            .navigationTitle("账户")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    struct LoginView: View {
        @Environment(\.dismiss) var dismiss
        @AppStorage("AccountToken") var accountToken = ""
        @AppStorage("CachedUserName") var cachedUserName = ""
        @State var usernameInput = ""
        @State var passwordInput = ""
        @State var isLoggingIn = false
        var body: some View {
            Form {
                Section {
                    TextField("用户名", text: $usernameInput)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $passwordInput)
                }
                Section {
                    Button(action: {
                        isLoggingIn = true
                        requestJSON("https://api.asmr.one/api/auth/me", method: .post, parameters: ["name": usernameInput, "password": passwordInput], encoding: JSONEncoding.default) { respJson, isSuccess in
                            if isSuccess {
                                if let token = respJson["token"].string, let username = respJson["user"]["name"].string {
                                    accountToken = token
                                    cachedUserName = username
                                    dismiss()
                                } else if let error = respJson["error"].string {
                                    NKTipper.automaticStyle.present(text: error, symbol: "xmark.circle.fill")
                                } else {
                                    NKTipper.automaticStyle.present(text: "未知错误", symbol: "xmark.circle.fill")
                                }
                            }
                            isLoggingIn = false
                        }
                    }, label: {
                        if !isLoggingIn {
                            Text("登录")
                        } else {
                            ProgressView()
                                .centerAligned()
                        }
                    })
                    .disabled(usernameInput.isEmpty || passwordInput.isEmpty || isLoggingIn)
                }
            }
            .navigationTitle("登录")
            .interactiveDismissDisabled(!usernameInput.isEmpty || !passwordInput.isEmpty)
        }
    }
    struct RegisterView: View {
        @Environment(\.dismiss) var dismiss
        @AppStorage("AccountToken") var accountToken = ""
        @AppStorage("CachedUserName") var cachedUserName = ""
        @State var usernameInput = ""
        @State var passwordInput = ""
        @State var confirmPasswordInput = ""
        @State var isRegistering = false
        var body: some View {
            Form {
                Section {
                    TextField("用户名", text: $usernameInput)
                        .autocorrectionDisabled()
                    SecureField("密码", text: $passwordInput)
                    SecureField("确认密码", text: $confirmPasswordInput)
                }
                Section {
                    Button(action: {
                        isRegistering = true
                        requestJSON("https://api.asmr.one/api/auth/reg", method: .post, parameters: ["name": usernameInput, "password": passwordInput, "recommenderUuid": UUID().uuidString], encoding: JSONEncoding.default) { respJson, isSuccess in
                            if isSuccess {
                                if let token = respJson["token"].string, let username = respJson["user"]["name"].string {
                                    accountToken = token
                                    cachedUserName = username
                                    dismiss()
                                } else if let error = respJson["error"].string {
                                    NKTipper.automaticStyle.present(text: error, symbol: "xmark.circle.fill")
                                } else {
                                    NKTipper.automaticStyle.present(text: "未知错误", symbol: "xmark.circle.fill")
                                }
                            }
                            isRegistering = false
                        }
                    }, label: {
                        if !isRegistering {
                            Text("注册")
                        } else {
                            ProgressView()
                                .centerAligned()
                        }
                    })
                    .disabled(usernameInput.isEmpty || passwordInput.isEmpty || passwordInput != confirmPasswordInput || isRegistering)
                }
            }
            .navigationTitle("注册")
            .interactiveDismissDisabled(!usernameInput.isEmpty || !passwordInput.isEmpty || !confirmPasswordInput.isEmpty)
        }
    }
}
