//
//  ViewExtensions.swift
//  Hydrate
//
//  Created by memz233 on 6/22/26.
//

import SwiftUI

extension View {
    func inversedMask<Mask: View>(
        @ViewBuilder content: () -> Mask
    ) -> some View {
        mask {
            Rectangle()
                .overlay {
                    content()
                        .blendMode(.destinationOut)
                }
        }
    }
}
