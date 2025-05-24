//
//  CrashCurseAppApp.swift
//  CrashCurseApp
//
//  Created by Alexander Denysiuk on 22.05.2025.
//

import SwiftUI
import UIKit

@main
struct CrashCurseAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            // Use a SwiftUI wrapper around our UIKit main controller
            MainTabControllerRepresentable()
        }
    }
}

// SwiftUI wrapper for our UIKit MainTabController
struct MainTabControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> MainTabController {
        return MainTabController()
    }
    
    func updateUIViewController(_ uiViewController: MainTabController, context: Context) {
        // Updates happen here
    }
}
