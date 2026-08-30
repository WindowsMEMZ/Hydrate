//
//  Marquee.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import SwiftUI
import Observation

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
    
    /// Synchronizes all overflowing marquee views in this hierarchy.
    func marqueeGroup() -> some View {
        modifier(MarqueeGroupModifier())
    }
}

@MainActor
@Observable
private final class MarqueeCoordinator {
    private(set) var startDate = Date()
    private(set) var movementDuration: TimeInterval = 7.5
    private var distances: [UUID: CGFloat] = [:]
    
    let pauseDuration: TimeInterval = 4.5
    
    func update(id: UUID, distance: CGFloat?) {
        let oldDistance = distances[id]
        if let distance, distance > 0 {
            guard oldDistance == nil || abs(oldDistance! - distance) > 0.5 else {
                return
            }
            distances[id] = distance
        } else {
            guard oldDistance != nil else { return }
            distances[id] = nil
        }
        updateTiming()
    }
    
    func remove(id: UUID) {
        guard distances.removeValue(forKey: id) != nil else { return }
        updateTiming()
    }
    
    private func updateTiming() {
        let longestDistance = distances.values.max() ?? 0
        movementDuration = min(max(TimeInterval(longestDistance / 40), 5), 30)
        startDate = Date()
    }
}

private struct MarqueeCoordinatorKey: EnvironmentKey {
    static let defaultValue: MarqueeCoordinator? = nil
}

private extension EnvironmentValues {
    var marqueeCoordinator: MarqueeCoordinator? {
        get { self[MarqueeCoordinatorKey.self] }
        set { self[MarqueeCoordinatorKey.self] = newValue }
    }
}

private struct MarqueeGroupModifier: ViewModifier {
    @State private var coordinator = MarqueeCoordinator()
    
    func body(content: Content) -> some View {
        content.environment(\.marqueeCoordinator, coordinator)
    }
}

private struct MarqueeModifier: ViewModifier {
    var leadingFade: CGFloat = 5
    var trailingFade: CGFloat = 5
    
    @Environment(\.marqueeCoordinator) private var groupedCoordinator
    @State private var localCoordinator = MarqueeCoordinator()
    @State private var contentSize = CGSize.zero
    @State private var containerSize = CGSize.zero
    @State private var participantID = UUID()
    
    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !needsScrolling)) { context in
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    content
                        .frame(maxWidth: .infinity)
                        .background {
                            GeometryReader { contentGeometry in
                                Color.clear
                                    .onChange(of: contentGeometry.size, initial: true) {
                                        contentSize = contentGeometry.size
                                    }
                            }
                        }
                        .onChange(of: geometry.size, initial: true) {
                            containerSize = geometry.size
                        }
                    if needsScrolling {
                        content
                            .offset(x: contentSize.width + spacing)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: contentOffset(at: context.date))
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
            }
        }
        .frame(height: contentSize.height, alignment: .leading)
        .onChange(of: scrollDistance, initial: true) {
            coordinator.update(
                id: participantID,
                distance: needsScrolling ? scrollDistance : nil
            )
        }
        .onDisappear {
            coordinator.remove(id: participantID)
        }
    }
    
    private var coordinator: MarqueeCoordinator {
        groupedCoordinator ?? localCoordinator
    }
    
    private let spacing: CGFloat = 40
    
    private var needsScrolling: Bool {
        contentSize.width > containerSize.width
    }
    
    private var scrollDistance: CGFloat {
        contentSize.width + spacing
    }
    
    private func contentOffset(at date: Date) -> CGFloat {
        guard needsScrolling else { return leadingFade }
        
        let movementDuration = coordinator.movementDuration
        let cycleDuration = coordinator.pauseDuration + movementDuration
        let elapsed = max(date.timeIntervalSince(coordinator.startDate), 0)
            .truncatingRemainder(dividingBy: cycleDuration)
        guard elapsed >= coordinator.pauseDuration else {
            return leadingFade
        }
        
        let progress = (elapsed - coordinator.pauseDuration) / movementDuration
        return leadingFade - scrollDistance * progress
    }
}
