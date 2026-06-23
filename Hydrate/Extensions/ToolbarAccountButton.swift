//
//  ToolbarAccountButton.swift
//  Hydrate
//
//  Created by memz233 on 6/24/26.
//

import SwiftUI
import DarockUI

extension View {
    func toolbarAccountButton() -> some View {
        modifier(ToolbarAccountButtonModifier())
    }
}

private struct ToolbarAccountButtonModifier: ViewModifier {
    @State private var isAccountManagementPresented = false
    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        isAccountManagementPresented = true
                    }, label: {
                        UsernameAvatarView()
                            .glassEffect(.regular.interactive(), in: Circle())
                            .frame(width: 42, height: 42)
                    })
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .sheet(isPresented: $isAccountManagementPresented) {
                AccountView()
            }
    }
}

struct UsernameAvatarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("CachedUserName") private var cachedUserName = ""
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    colorScheme == .dark
                    ? LinearGradient(colors: [
                        Color(hex: 0x5B576D),
                        Color(hex: 0x362D4F)
                    ], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [
                        Color(hex: 0xAAC3E5),
                        Color(hex: 0x7B87C1)
                    ], startPoint: .top, endPoint: .bottom)
                )
            Text(nameAbbr())
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
    }
    
    private func nameAbbr() -> String {
        var result = String(cachedUserName.components(separatedBy: .whitespaces)
            .compactMap {
                $0.first
            })
        if result.count < 2 {
            result = ""
            for character in cachedUserName where character.isUppercase {
                result.append(character)
            }
            if result.count < 2 {
                result = String(cachedUserName.prefix(2))
            }
        }
        
        if result.allSatisfy({ $0.isASCII }) {
            return String(result.prefix(2))
        } else {
            return String(result.prefix(1))
        }
    }
}
