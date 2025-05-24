import Foundation

// This file documents how the app is configured
// We're now using a SwiftUI app lifecycle with UIKit integration

/* App Structure:

1. App Entry Point: 
   - CrashCurseAppApp.swift - SwiftUI @main struct with UIApplicationDelegateAdaptor

2. UIKit Integration:
   - AppDelegate - NSObject conforming to UIApplicationDelegate
   - SceneDelegate - For window setup
   - MainTabController - UITabBarController for main navigation
   - Various UIViewController subclasses for each tab

3. Core Data:
   - Managed in AppDelegate with persistentContainer
   - LocalStorageService as a wrapper for Core Data operations

4. Configuration:
   - Build settings generate Info.plist automatically (GENERATE_INFOPLIST_FILE = YES)
   - Scene configuration happens in AppDelegate's configurationForConnecting method
*/

// This file contains configuration that would normally go in Info.plist
// Since this project is set to automatically generate Info.plist, we need to set these values in code

// Add this to your AppDelegate.swift in didFinishLaunchingWithOptions:
/*
 func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     // For scene-based lifecycle setup - ensure SceneDelegateClassName is set
     if let sceneConfigurationKey = Bundle.main.infoDictionary?["UIApplicationSceneManifest"] as? [String: Any],
        let sceneConfigs = sceneConfigurationKey["UISceneConfigurations"] as? [String: Any],
        var applicationScenes = sceneConfigs["UIWindowSceneSessionRoleApplication"] as? [[String: Any]] {
         
         // Ensure we have at least one scene configuration
         if applicationScenes.isEmpty {
             applicationScenes.append([:])
         }
         
         // Set the SceneDelegate class name
         applicationScenes[0]["UISceneDelegateClassName"] = "CrashCurseApp.SceneDelegate"
         
         // Set other scene configuration
         applicationScenes[0]["UISceneConfigurationName"] = "Default Configuration"
     }
     
     return true
 }
*/ 

// MARK: - App Configuration
struct AppConfiguration {
    
    // MARK: - API Configuration
    struct API {
        // Backend configuration
        static let backendURL = "https://mobile.labai.ws"
        static let localBackendURL = "http://localhost:8000"
        static let apiKey = "supersecretapikey"
        
        // ElevenLabs configuration
        static let elevenLabsAPIKey = "YOUR_ELEVENLABS_API_KEY" // Replace with your actual key
        static let elevenLabsBaseURL = "https://api.elevenlabs.io/v1"
        
        // Preferred backend URL (change for development/production)
        static var currentBackendURL: String {
            #if DEBUG
            return localBackendURL // Use local for development
            #else
            return backendURL // Use production for release
            #endif
        }
    }
    
    // MARK: - Voice Configuration
    struct Voice {
        // ElevenLabs voice settings
        static let defaultVoiceId = "21m00Tcm4TlvDq8ikWAM" // Rachel (English)
        static let ukrainianVoiceId = "pNInz6obpgDQGcFmaJgB" // Adam (multilingual)
        
        // Speech recognition settings
        static let defaultLanguage = "uk-UA"
        static let silenceThreshold: Double = 1.5
        static let minimumAudioLevel: Float = -40.0
        
        // Voice quality settings
        struct ElevenLabsSettings {
            static let stability: Double = 0.5
            static let similarityBoost: Double = 0.75
            static let style: Double = 0.5
            static let useSpeakerBoost = true
            static let modelId = "eleven_multilingual_v2"
        }
        
        // System TTS fallback settings
        struct SystemTTS {
            static let rate: Float = 0.5
            static let ukrainianRate: Float = 0.45
            static let pitchMultiplier: Float = 1.1
            static let volume: Float = 0.8
        }
    }
    
    // MARK: - App Settings
    struct App {
        static let smartModeEnabled = true
        static let autoSendEnabled = true
        static let feedbackEnabled = true
        
        // UI Configuration
        static let primaryColor = "systemBlue"
        static let recordingColor = "systemRed"
        static let processingColor = "systemOrange"
    }
    
    // MARK: - Development Flags
    struct Debug {
        static let enableVoiceLogging = true
        static let enableNetworkLogging = true
        static let enableAnalytics = false
        static let showDebugInfo = false
    }
}

// MARK: - Configuration Extensions
extension AppConfiguration {
    
    /// Check if ElevenLabs is properly configured
    static var isElevenLabsConfigured: Bool {
        return !API.elevenLabsAPIKey.isEmpty && 
               API.elevenLabsAPIKey != "YOUR_ELEVENLABS_API_KEY"
    }
    
    /// Get voice ID based on language
    static func voiceId(for language: String) -> String {
        if language.starts(with: "uk") {
            return Voice.ukrainianVoiceId
        }
        return Voice.defaultVoiceId
    }
    
    /// Log configuration status
    static func logConfigurationStatus() {
        print("🔧 App Configuration Status:")
        print("   Backend URL: \(API.currentBackendURL)")
        print("   ElevenLabs configured: \(isElevenLabsConfigured)")
        print("   Smart mode: \(App.smartModeEnabled)")
        print("   Debug mode: \(Debug.enableVoiceLogging)")
    }
} 