//
//  UIRepresentable.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/5/1.
//

import SwiftUI

struct GenericUIViewRepresentable: UIViewRepresentable {
    var view: UIView
    func makeUIView(context: Context) -> some UIView {
        view
    }
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

struct GenericUIViewControllerRepresentable: UIViewControllerRepresentable {
    var viewController: UIViewController
    func makeUIViewController(context: Context) -> UIViewController {
        viewController
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
