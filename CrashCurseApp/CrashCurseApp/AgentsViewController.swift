import UIKit
import Combine

class AgentsViewController: UIViewController {
    private let localStorageService = LocalStorageService()
    private var cancellables = Set<AnyCancellable>()
    private var agents: [AgentConfiguration] = []
    
    // UI Components
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(AgentCell.self, forCellReuseIdentifier: "AgentCell")
        return tableView
    }()
    
    private let addButton: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
    }()
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "AI agents help with different tasks in the app. Enable or disable agents to customize your experience."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.isHidden = true
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupNavigation()
        loadAgents()
        title = "AI Agents"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadAgents()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(tableView)
        view.addSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            infoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    private func setupNavigation() {
        addButton.target = self
        addButton.action = #selector(addAgentTapped)
        navigationItem.rightBarButtonItem = addButton
    }
    
    private func loadAgents() {
        localStorageService.fetchAgentConfigurations()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error fetching agents: \(error)")
                }
            }, receiveValue: { [weak self] agents in
                self?.agents = agents
                
                // If no agents exist, create some default ones
                if agents.isEmpty {
                    self?.createDefaultAgents()
                }
                
                self?.tableView.reloadData()
                self?.updateInfoLabelVisibility()
            })
            .store(in: &cancellables)
    }
    
    private func createDefaultAgents() {
        // Create a few default agents
        let defaultAgents = [
            (id: "assistant", name: "General Assistant", enabled: true),
            (id: "planner", name: "Planning Agent", enabled: true),
            (id: "researcher", name: "Research Agent", enabled: true),
            (id: "creative", name: "Creative Writer", enabled: false)
        ]
        
        for agent in defaultAgents {
            localStorageService.saveAgentConfiguration(
                agentId: agent.id,
                name: agent.name,
                settings: nil,
                isEnabled: agent.enabled
            )
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error creating default agent \(agent.id): \(error)")
                }
            }, receiveValue: { _ in
                print("Successfully created default agent: \(agent.name)")
            })
            .store(in: &cancellables)
        }
        
        // Reload after creating defaults
        loadAgents()
    }
    
    private func updateInfoLabelVisibility() {
        infoLabel.isHidden = !agents.isEmpty
        tableView.isHidden = agents.isEmpty
    }
    
    @objc private func addAgentTapped() {
        let alert = UIAlertController(title: "Add New Agent", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Agent Name"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Agent ID (e.g., 'assistant')"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self else { return }
            guard let name = alert.textFields?[0].text, !name.isEmpty,
                  let agentId = alert.textFields?[1].text, !agentId.isEmpty else {
                return
            }
            
            self.localStorageService.saveAgentConfiguration(
                agentId: agentId,
                name: name,
                settings: nil,
                isEnabled: true
            )
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error creating agent: \(error)")
                }
            }, receiveValue: { _ in
                print("Successfully created agent: \(name)")
                self.loadAgents()
            })
            .store(in: &self.cancellables)
        })
        
        present(alert, animated: true)
    }
    
    private func toggleAgentEnabled(_ agent: AgentConfiguration) {
        let isEnabled = !agent.isEnabled
        
        localStorageService.saveAgentConfiguration(
            agentId: agent.agentId ?? "",
            name: agent.name ?? "",
            settings: agent.settings,
            isEnabled: isEnabled
        )
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Error updating agent: \(error)")
            }
        }, receiveValue: { _ in
            print("Successfully updated agent status")
        })
        .store(in: &cancellables)
        
        // Update locally for immediate UI feedback
        agent.isEnabled = isEnabled
        tableView.reloadData()
    }
    
    private func showAgentDetails(_ agent: AgentConfiguration) {
        let alert = UIAlertController(
            title: agent.name,
            message: "Agent ID: \(agent.agentId ?? "")\nStatus: \(agent.isEnabled ? "Enabled" : "Disabled")",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.editAgent(agent)
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteAgent(agent)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func editAgent(_ agent: AgentConfiguration) {
        let alert = UIAlertController(title: "Edit Agent", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Agent Name"
            textField.text = agent.name
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            guard let name = alert.textFields?[0].text, !name.isEmpty else {
                return
            }
            
            self.localStorageService.saveAgentConfiguration(
                agentId: agent.agentId ?? "",
                name: name,
                settings: agent.settings,
                isEnabled: agent.isEnabled
            )
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error updating agent: \(error)")
                }
            }, receiveValue: { _ in
                print("Successfully updated agent")
                self.loadAgents()
            })
            .store(in: &self.cancellables)
        })
        
        present(alert, animated: true)
    }
    
    private func deleteAgent(_ agent: AgentConfiguration) {
        let context = localStorageService.viewContext
        context.delete(agent)
        localStorageService.saveContext()
        
        if let index = agents.firstIndex(of: agent) {
            agents.remove(at: index)
            tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            updateInfoLabelVisibility()
        }
    }
}

// MARK: - UITableViewDataSource
extension AgentsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return agents.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "AgentCell", for: indexPath) as? AgentCell else {
            return UITableViewCell()
        }
        
        let agent = agents[indexPath.row]
        cell.configure(with: agent) { [weak self] in
            self?.toggleAgentEnabled(agent)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Available Agents"
    }
}

// MARK: - UITableViewDelegate
extension AgentsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let agent = agents[indexPath.row]
        showAgentDetails(agent)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
}

// MARK: - Agent Cell
class AgentCell: UITableViewCell {
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.boldSystemFont(ofSize: 16)
        return label
    }()
    
    private let idLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let enableSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.onTintColor = .systemGreen
        return switchControl
    }()
    
    private var switchToggleHandler: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(nameLabel)
        contentView.addSubview(idLabel)
        contentView.addSubview(enableSwitch)
        
        enableSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: enableSwitch.leadingAnchor, constant: -8),
            
            idLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            idLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            idLabel.trailingAnchor.constraint(equalTo: enableSwitch.leadingAnchor, constant: -8),
            idLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            enableSwitch.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            enableSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    @objc private func switchValueChanged() {
        switchToggleHandler?()
    }
    
    func configure(with agent: AgentConfiguration, toggleHandler: @escaping () -> Void) {
        nameLabel.text = agent.name
        idLabel.text = "ID: \(agent.agentId ?? "unknown")"
        enableSwitch.isOn = agent.isEnabled
        switchToggleHandler = toggleHandler
    }
} 