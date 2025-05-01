//
//  String+.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/1.
//

import Foundation

extension String: @retroactive Identifiable {
    public var id: String { self }
}
