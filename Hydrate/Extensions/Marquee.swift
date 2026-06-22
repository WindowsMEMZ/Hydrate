//
//  Marquee.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import SwiftUI

extension View {
    func marquee(
        leadingFade: CGFloat = 5,
        trailingFade: CGFloat = 5
    ) -> some View {
        modifier(MarqueeModifier(
            leadingFade: leadingFade,
            trailingFade: trailingFade
        ))
    }
}

private struct MarqueeModifier: ViewModifier {
    var leadingFade: CGFloat = 5
    var trailingFade: CGFloat = 5
    @State private var contentSize = CGSize.zero
    @State private var containerSize = CGSize.zero
    @State private var contentOffsetX: CGFloat = 0
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                content
                    .frame(maxWidth: .infinity)
                    .background {
                        GeometryReader { geometry in
                            Color.clear
                                .onChange(of: geometry.size, initial: true) {
                                    contentSize = geometry.size
                                }
                        }
                    }
                    .onChange(of: geometry.size, initial: true) {
                        containerSize = geometry.size
                    }
                if needsScrolling {
                    content
                        .offset(x: contentSize.width + 40)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .offset(x: contentOffsetX)
            .animation(
                needsScrolling
                ? .easeOut(duration: 7.5)
                    .delay(4.5)
                    .repeatForever(autoreverses: false)
                : .linear(duration: 0),
                value: contentOffsetX
            )
            .padding(.leading, -leadingFade)
            .padding(.trailing, -trailingFade)
            .mask(alignment: .leading) {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0.3), .black],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: leadingFade)
                    Rectangle()
                    LinearGradient(
                        colors: [.black, .black.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: trailingFade)
                }
                .frame(
                    width: containerSize.width + leadingFade + trailingFade,
                    height: contentSize.height
                )
                .offset(x: -leadingFade)
            }
            .onAppear {
                withTransaction(hardTransaction) {
                    contentOffsetX = leadingFade
                }
            }
            .onChange(of: needsScrolling, initial: true) {
                if needsScrolling {
                    withAnimation {
                        contentOffsetX = -contentSize.width - 40 + leadingFade
                    }
                } else {
                    withTransaction(hardTransaction) {
                        withAnimation {
                            contentOffsetX = leadingFade
                        }
                    }
                }
            }
        }
        .frame(height: contentSize.height, alignment: .leading)
    }
    
    private var needsScrolling: Bool {
        contentSize.width > containerSize.width
    }
    
    private var hardTransaction: Transaction {
        var result = Transaction()
        result.disablesAnimations = true
        return result
    }
}
