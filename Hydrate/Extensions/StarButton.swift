//
//  StarButton.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/1.
//

import SwiftUI

struct StarButton: View {
    @Binding var isStarred: Bool
    var action: () -> Void
    @State var isStarAnimating = false
    var body: some View {
        ZStack {
            Button(action: {
                if !isStarred {
                    isStarAnimating = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        var transaction = Transaction(animation: .easeIn(duration: 0.1))
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            isStarAnimating = false
                        }
                    }
                }
                action()
            }, label: {
                Image(systemName: "star")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(isStarred ? 0 : 1)
            })
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            Image(systemName: "star.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(isStarAnimating ? 1.2 : 1)
                .animation(.smooth(duration: 1.4), value: isStarAnimating)
                .shadow(color: isStarAnimating ? .white : .clear, radius: 4, x: 1.5, y: 1.5)
                .opacity(isStarred ? 1 : 0)
                .allowsHitTesting(false)
        }
    }
}
