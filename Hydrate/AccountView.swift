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
import DarockFoundation

struct AccountView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("AccountToken") var accountToken = ""
    @AppStorage("CachedUserName") var cachedUserName = ""
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
                    }
                    Section {
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
            }
            .navigationTitle("账户")
            .withDismissButton {
                dismiss()
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
        }
    }
}
