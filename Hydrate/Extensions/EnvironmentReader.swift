//
//  EnvironmentReader.swift
//  Hydrate
//
//  Created by memz233 on 6/11/26.
//

import SwiftUI

struct EnvironmentReader<Content: View, Value>: View {
    private var environment: Environment<Value>
    private var content: (Value) -> Content
    
    init(
        _ keyPath: KeyPath<EnvironmentValues, Value>,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.environment = Environment(keyPath)
        self.content = content
    }
    init(
        _ objectType: Value.Type,
        @ViewBuilder content: @escaping (Value) -> Content
    ) where Value: AnyObject, Value: Observable {
        self.environment = Environment(objectType)
        self.content = content
    }
//    init<T>(
//        _ objectType: T.Type,
//        @ViewBuilder content: @escaping (Value) -> Content
//    ) where Value == T?, T: AnyObject, T: Observable {
//        self.environment = Environment(objectType)
//        self.content = content
//    }
    
    var body: some View {
        content(environment.wrappedValue)
    }
}
