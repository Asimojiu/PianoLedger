import SwiftUI
import Firebase

@main
struct PianoLedgerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var firebase = FirebaseManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if firebase.isAuthenticated {
                    PianoListView()
                } else {
                    LoginView()
                }
            }
            .onAppear {
                configureAppearance()
            }
        }
    }
    
    private func configureAppearance() {
        // Customize navigation bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = .systemBackground
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        
        // Customize tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        
        // Green tint color
        UIView.appearance(whenConvertingTo: UIButton.self).tintColor = .systemGreen
    }
}
