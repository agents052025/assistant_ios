import UIKit

class MainTabController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
    }

    private func setupTabs() {
        let chatVC = ChatViewController()
        chatVC.tabBarItem = UITabBarItem(title: "Chat", image: UIImage(systemName: "message.fill"), tag: 0)

        let planningVC = PlanningViewController()
        planningVC.tabBarItem = UITabBarItem(title: "Plan", image: UIImage(systemName: "calendar"), tag: 1)

        let voiceVC = VoiceViewController() // Placeholder, might be a modal or integrated differently
        voiceVC.tabBarItem = UITabBarItem(title: "Voice", image: UIImage(systemName: "mic.fill"), tag: 2)

        let agentsVC = AgentsViewController()
        agentsVC.tabBarItem = UITabBarItem(title: "Agents", image: UIImage(systemName: "person.3.fill"), tag: 3)
        
        let settingsVC = SettingsViewController()
        settingsVC.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape.fill"), tag: 4)

        // To make the ViewControllers part of the tab bar, they need to be embedded in NavigationControllers
        // if you want navigation capabilities within each tab.
        let chatNav = UINavigationController(rootViewController: chatVC)
        let planningNav = UINavigationController(rootViewController: planningVC)
        let voiceNav = UINavigationController(rootViewController: voiceVC) // Or handle differently
        let agentsNav = UINavigationController(rootViewController: agentsVC)
        let settingsNav = UINavigationController(rootViewController: settingsVC)

        viewControllers = [chatNav, planningNav, voiceNav, agentsNav, settingsNav]

        // Optional: Customize tab bar appearance
        tabBar.tintColor = .systemBlue // Example color
        // tabBar.barTintColor = .white // For older iOS versions or specific styles
        // tabBar.isTranslucent = false
    }
} 