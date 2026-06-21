//
//  HydrateApp.swift
//  Hydrate
//
//  Created by Mark Chan on 2025/4/30.
//

import TipKit
import Combine
import SwiftUI
import AVFoundation
import DarockFoundation

@main
struct HydrateApp: App {
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        
        // Don't say lazy
        _ = DownloadManager.shared
        
        try? Tips.configure()
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        if connectingSceneSession.role == .windowApplication {
            config.delegateClass = SceneDelegate.self
        }
        return config
    }
}

@Observable
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    weak var windowScene: UIWindowScene?
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }
        self.windowScene = scene
    }
    
    var keyWindowBounds: CGRect {
        windowScene?.keyWindow?.bounds ?? .zero
    }
}
