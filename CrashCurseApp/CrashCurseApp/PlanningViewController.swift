import UIKit
import Combine
import CoreData

class PlanningViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    private let networkService = NetworkService()
    private let localStorageService = LocalStorageService()
    private var events: [EventEntity] = []
    private var tasks: [UserTask] = []
    
    // UI Components
    private let segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Events", "Tasks"])
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        return control
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .singleLine
        return tableView
    }()
    
    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        return button
    }()
    
    private var isShowingEvents = true

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupActions()
        loadData()
        title = "Planning"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh data when view appears
        loadData()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        view.addSubview(addButton)
        
        NSLayoutConstraint.activate([
            // Segmented control constraints
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // TableView constraints
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Add button constraints
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addButton.widthAnchor.constraint(equalToConstant: 50),
            addButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupTableView() {
        tableView.register(EventCell.self, forCellReuseIdentifier: "EventCell")
        tableView.register(TaskCell.self, forCellReuseIdentifier: "TaskCell")
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func setupActions() {
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        addButton.addTarget(self, action: #selector(addItem), for: .touchUpInside)
    }
    
    private func loadData() {
        if isShowingEvents {
            loadEvents()
        } else {
            loadTasks()
        }
    }
    
    private func loadEvents() {
        localStorageService.fetchEvents()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error fetching events: \(error)")
                }
            }, receiveValue: { [weak self] events in
                self?.events = events
                self?.tableView.reloadData()
            })
            .store(in: &cancellables)
    }
    
    private func loadTasks() {
        localStorageService.fetchTasks()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error fetching tasks: \(error)")
                }
            }, receiveValue: { [weak self] tasks in
                self?.tasks = tasks
                self?.tableView.reloadData()
            })
            .store(in: &cancellables)
    }
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        isShowingEvents = sender.selectedSegmentIndex == 0
        loadData()
    }
    
    @objc private func addItem() {
        if isShowingEvents {
            showAddEventAlert()
        } else {
            showAddTaskAlert()
        }
    }
    
    private func showAddEventAlert() {
        let alert = UIAlertController(title: "New Event", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Event title"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Location (optional)"
        }
        
        // Add a date picker - in a real app, you'd want a more robust solution
        // For simplicity, we're just using basic text field input
        alert.addTextField { textField in
            textField.placeholder = "Date (yyyy-MM-dd HH:mm)"
            textField.text = self.formatDate(Date())
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let title = alert.textFields?[0].text, !title.isEmpty,
                  let dateString = alert.textFields?[2].text,
                  let date = self?.parseDate(dateString) else {
                return
            }
            
            let location = alert.textFields?[1].text
            
            self?.createAndSaveEvent(title: title, location: location, startDate: date)
        })
        
        present(alert, animated: true)
    }
    
    private func showAddTaskAlert() {
        let alert = UIAlertController(title: "New Task", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Task description"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Due date (yyyy-MM-dd, optional)"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let description = alert.textFields?[0].text, !description.isEmpty else {
                return
            }
            
            var dueDate: Date? = nil
            if let dueDateString = alert.textFields?[1].text, !dueDateString.isEmpty {
                dueDate = self?.parseDate(dueDateString)
            }
            
            self?.createAndSaveTask(description: description, dueDate: dueDate)
        })
        
        present(alert, animated: true)
    }
    
    private func createAndSaveEvent(title: String, location: String?, startDate: Date) {
        let context = localStorageService.viewContext
        let event = EventEntity(context: context)
        event.id = UUID()
        event.title = title
        event.location = location
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)
        
        localStorageService.saveContext()
        
        // Also send to network service
        networkService.createEvent(
            title: title,
            startDate: startDate,
            endDate: Calendar.current.date(byAdding: .hour, value: 1, to: startDate),
            location: location,
            notes: nil
        )
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error saving event to server: \(error)")
                }
            }, receiveValue: { _ in
                print("Event successfully saved to server")
            })
            .store(in: &cancellables)
        
        loadEvents()
    }
    
    private func createAndSaveTask(description: String, dueDate: Date?) {
        let context = localStorageService.viewContext
        let task = UserTask(context: context)
        task.id = UUID()
        task.taskDescription = description
        task.creationDate = Date()
        task.dueDate = dueDate
        task.isCompleted = false
        
        localStorageService.saveContext()
        
        // Also send to network service
        networkService.createReminder(title: description, dueDate: dueDate, notes: nil)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error saving task to server: \(error)")
                }
            }, receiveValue: { _ in
                print("Task successfully saved to server")
            })
            .store(in: &cancellables)
        
        loadTasks()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: string) {
            return date
        }
        
        // Try just the date format
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
    
    private func toggleTaskCompletion(task: UserTask) {
        task.isCompleted = !task.isCompleted
        localStorageService.saveContext()
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension PlanningViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isShowingEvents ? events.count : tasks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isShowingEvents {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "EventCell", for: indexPath) as? EventCell else {
                return UITableViewCell()
            }
            
            let event = events[indexPath.row]
            cell.configure(with: event)
            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "TaskCell", for: indexPath) as? TaskCell else {
                return UITableViewCell()
            }
            
            let task = tasks[indexPath.row]
            cell.configure(with: task) { [weak self] in
                self?.toggleTaskCompletion(task: task)
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate
extension PlanningViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let context = localStorageService.viewContext
            
            if isShowingEvents {
                let event = events[indexPath.row]
                context.delete(event)
                events.remove(at: indexPath.row)
            } else {
                let task = tasks[indexPath.row]
                context.delete(task)
                tasks.remove(at: indexPath.row)
            }
            
            localStorageService.saveContext()
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}

// MARK: - Custom Cells
class EventCell: UITableViewCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.boldSystemFont(ofSize: 16)
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemGray
        return label
    }()
    
    private let locationLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemGray
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(dateLabel)
        contentView.addSubview(locationLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            locationLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            locationLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            locationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            locationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with event: EventEntity) {
        titleLabel.text = event.title
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy HH:mm"
        
        if let startDate = event.startDate {
            dateLabel.text = dateFormatter.string(from: startDate)
        } else {
            dateLabel.text = "No date"
        }
        
        if let location = event.location, !location.isEmpty {
            locationLabel.text = "📍 \(location)"
            locationLabel.isHidden = false
        } else {
            locationLabel.isHidden = true
        }
    }
}

class TaskCell: UITableViewCell {
    private let taskLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    
    private let dueDateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .systemGray
        return label
    }()
    
    private let checkboxButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "circle"), for: .normal)
        button.tintColor = .systemBlue
        return button
    }()
    
    private var completionToggleHandler: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(checkboxButton)
        contentView.addSubview(taskLabel)
        contentView.addSubview(dueDateLabel)
        
        checkboxButton.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            checkboxButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            checkboxButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkboxButton.widthAnchor.constraint(equalToConstant: 24),
            checkboxButton.heightAnchor.constraint(equalToConstant: 24),
            
            taskLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            taskLabel.leadingAnchor.constraint(equalTo: checkboxButton.trailingAnchor, constant: 12),
            taskLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            dueDateLabel.topAnchor.constraint(equalTo: taskLabel.bottomAnchor, constant: 4),
            dueDateLabel.leadingAnchor.constraint(equalTo: taskLabel.leadingAnchor),
            dueDateLabel.trailingAnchor.constraint(equalTo: taskLabel.trailingAnchor),
            dueDateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    @objc private func checkboxTapped() {
        completionToggleHandler?()
    }
    
    func configure(with task: UserTask, completionHandler: @escaping () -> Void) {
        taskLabel.text = task.taskDescription
        completionToggleHandler = completionHandler
        
        // Apply strikethrough if completed
        if task.isCompleted {
            let attributedString = NSAttributedString(
                string: task.taskDescription ?? "",
                attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            )
            taskLabel.attributedText = attributedString
            checkboxButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
        } else {
            taskLabel.attributedText = nil
            taskLabel.text = task.taskDescription
            checkboxButton.setImage(UIImage(systemName: "circle"), for: .normal)
        }
        
        // Set due date if available
        if let dueDate = task.dueDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, yyyy"
            dueDateLabel.text = "Due: \(dateFormatter.string(from: dueDate))"
            
            // Highlight overdue tasks
            if !task.isCompleted && dueDate < Date() {
                dueDateLabel.textColor = .systemRed
            } else {
                dueDateLabel.textColor = .systemGray
            }
            
            dueDateLabel.isHidden = false
        } else {
            dueDateLabel.isHidden = true
        }
    }
}