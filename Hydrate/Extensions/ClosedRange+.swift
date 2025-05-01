//
//  ClosedRange+.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import Foundation

extension Array<ClosedRange<Double>> {
    var allBounds: [Double] {
        var result = [Double]()
        for range in self {
            result.append(range.lowerBound)
            result.append(range.upperBound)
        }
        return result
    }
}
