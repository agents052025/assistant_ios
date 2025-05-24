import UIKit
import Combine

class SettingsViewController: UIViewController {
    private let localStorageService = LocalStorageService()
    private var cancellables = Set<AnyCancellable>()
    
    // Settings sections and options
    private enum Section: Int, CaseIterable {
        case general, notifications, agents, appearance, about
        
        var title: String {
            switch self {
            case .general:
                return "General"
            case .notifications:
                return "Notifications"
            case .agents:
                return "AI Agents"
            case .appearance:
                return "Appearance"
            case .about:
                return "About"
            }
        }
    }
    
    // UI Components
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "SwitchCell")
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        title = "Settings"
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // Save a boolean setting
    private func saveBoolSetting(key: String, value: Bool) {
        localStorageService.savePreference(key: key, value: String(value))
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error saving preference \(key): \(error)")
                }
            }, receiveValue: { _ in
                print("Successfully saved preference \(key)")
            })
            .store(in: &cancellables)
    }
    
    // Retrieve a boolean setting with a default value
    private func getBoolSetting(key: String, defaultValue: Bool = false) -> Bool {
        let key = key
        let defaultValue = defaultValue
        
        var result = defaultValue
        
        localStorageService.fetchPreference(forKey: key)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error fetching preference \(key): \(error)")
                }
            }, receiveValue: { value in
                if let value = value {
                    result = value.lowercased() == "true"
                }
            })
            .store(in: &cancellables)
        
        return result
    }
    
    private func showAppInfo() {
        let alertController = UIAlertController(
            title: "CrashCurse Assistant",
            message: "Version 1.0.0\n© 2023 CrashCurse Inc.\n\nAn AI-powered personal assistant with multimodal capabilities.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}

// MARK: - UITableViewDataSource
extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .general:
            return 2
        case .notifications:
            return 3
        case .agents:
            return 1
        case .appearance:
            return 2
        case .about:
            return 2
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        return sectionType.title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch section {
        case .general:
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
                cell.textLabel?.text = "Language"
                cell.detailTextLabel?.text = "English"
                cell.accessoryType = .disclosureIndicator
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
                cell.textLabel?.text = "Save Chat History"
                cell.switchControl.isOn = getBoolSetting(key: "saveChatHistory", defaultValue: true)
                cell.switchToggleHandler = { isOn in
                    self.saveBoolSetting(key: "saveChatHistory", value: isOn)
                }
                return cell
            }
            
        case .notifications:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Allow Notifications"
                cell.switchControl.isOn = getBoolSetting(key: "allowNotifications", defaultValue: true)
                cell.switchToggleHandler = { isOn in
                    self.saveBoolSetting(key: "allowNotifications", value: isOn)
                }
            case 1:
                cell.textLabel?.text = "Event Reminders"
                cell.switchControl.isOn = getBoolSetting(key: "eventReminders", defaultValue: true)
                cell.switchToggleHandler = { isOn in
                    self.saveBoolSetting(key: "eventReminders", value: isOn)
                }
            case 2:
                cell.textLabel?.text = "Task Reminders"
                cell.switchControl.isOn = getBoolSetting(key: "taskReminders", defaultValue: true)
                cell.switchToggleHandler = { isOn in
                    self.saveBoolSetting(key: "taskReminders", value: isOn)
                }
            default:
                break
            }
            return cell
            
        case .agents:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
            cell.textLabel?.text = "Manage AI Agents"
            cell.accessoryType = .disclosureIndicator
            return cell
            
        case .appearance:
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
                cell.textLabel?.text = "Theme"
                cell.detailTextLabel?.text = "System Default"
                cell.accessoryType = .disclosureIndicator
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
                cell.textLabel?.text = "Dark Mode"
                cell.switchControl.isOn = getBoolSetting(key: "darkMode", defaultValue: false)
                cell.switchToggleHandler = { isOn in
                    self.saveBoolSetting(key: "darkMode", value: isOn)
                }
                return cell
            }
            
        case .about:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
            if indexPath.row == 0 {
                cell.textLabel?.text = "App Information"
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "Privacy Policy"
                cell.accessoryType = .disclosureIndicator
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate
extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let section = Section(rawValue: indexPath.section) else { return }
        
        switch section {
        case .general:
            if indexPath.row == 0 {
                // Show language selection
                print("Language selection tapped")
            }
            
        case .agents:
            // Navigate to agents management
            print("Agents management tapped")
            
        case .appearance:
            if indexPath.row == 0 {
                // Show theme selection
                print("Theme selection tapped")
            }
            
        case .about:
            if indexPath.row == 0 {
                // Show app info
                showAppInfo()
            } else {
                // Show privacy policy
                print("Privacy policy tapped")
            }
            
        default:
            break
        }
    }
}

// MARK: - Custom Cells
class SwitchTableViewCell: UITableViewCell {
    var switchToggleHandler: ((Bool) -> Void)?
    
    lazy var switchControl: UISwitch = {
        let switchControl = UISwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.onTintColor = .systemBlue
        switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
        return switchControl
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(switchControl)
        
        NSLayoutConstraint.activate([
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            switchControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    @objc private func switchValueChanged(_ sender: UISwitch) {
        switchToggleHandler?(sender.isOn)
    }
} 