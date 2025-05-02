//
//  AboutView.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/2.
//

import SwiftUI
import DarockUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                Link(destination: URL(string: "https://github.com/WindowsMEMZ/Hydrate")!) {
                    HStack {
                        Text(verbatim: "GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .fontWeight(.medium)
                    }
                }
            } header: {
                Text("源代码")
                    .textCase(nil)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, -15)
            }
            Section {
                Text("WindowsMEMZ")
            } header: {
                Text("App 开发")
                    .textCase(nil)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, -15)
            }
            Section {
                SinglePackageBlock(name: "Alamofire", license: "MIT license")
                SinglePackageBlock(name: "BottomSheet", license: "MIT license")
                SinglePackageBlock(name: "swiftui-cached-async-image", license: "MIT license")
                SinglePackageBlock(name: "swiftui-introspect", license: "MIT license")
                SinglePackageBlock(name: "SwiftyJSON", license: "MIT license")
            } header: {
                Text("软件包引用")
                    .textCase(nil)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, -15)
            }
            Section {
                Text("Hydrate 用于学习 Swift 以及 SwiftUI 开发以及供个人、非商业性地使用，内容版权属于 [asmr.one](https://asmr.one) 或音声原发布平台以及音声作者本人。")
            } header: {
                Text("Disclaimer")
                    .textCase(nil)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .padding(.horizontal, -15)
            }
        }
        .navigationTitle("关于 App")
    }
    
    struct SinglePackageBlock: View {
        var name: String
        var license: String
        var body: some View {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(Color(hex: 0xa06f2f))
                VStack {
                    HStack {
                        Text(name)
                        Spacer()
                    }
                    HStack {
                        Text(license)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
        }
    }
}
