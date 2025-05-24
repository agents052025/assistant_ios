import UIKit
import Combine
import CoreData
import EventKit
import Speech

class ChatViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    private let networkService = NetworkService()
    private let localStorageService = LocalStorageService()
    private let integrationService = IntegrationService()
    private let voiceService = VoiceService()
    private var messages: [ChatMessage] = []
    private var isListening = false
    
    // Backend status tracking
    private var backendStatus: Bool = false
    
    // UI Components
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        return tableView
    }()
    
    private let backendStatusView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 8
        return view
    }()
    
    private let backendStatusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.text = "Перевірка серверів..."
        return label
    }()
    
    private let messageInputView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray6
        return view
    }()
    
    private let messageTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "Type a message..."
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .systemBackground
        return textField
    }()
    
    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        button.tintColor = .systemBlue
        return button
    }()
    
    private let voiceButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        button.tintColor = .systemBlue
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupActions()
        loadMessages()
        checkBackendStatus()
        title = "Chat Assistant"
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add tableView
        view.addSubview(tableView)
        
        // Add backend status view
        view.addSubview(backendStatusView)
        backendStatusView.addSubview(backendStatusLabel)
        
        // Add message input view
        view.addSubview(messageInputView)
        messageInputView.addSubview(messageTextField)
        messageInputView.addSubview(sendButton)
        messageInputView.addSubview(voiceButton)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // TableView constraints
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: messageInputView.topAnchor),
            
            // Backend status view constraints
            backendStatusView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            backendStatusView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backendStatusView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backendStatusView.bottomAnchor.constraint(equalTo: tableView.topAnchor),
            
            // Message input view constraints
            messageInputView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            messageInputView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messageInputView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            messageInputView.heightAnchor.constraint(equalToConstant: 60),
            
            // Text field constraints
            messageTextField.leadingAnchor.constraint(equalTo: messageInputView.leadingAnchor, constant: 16),
            messageTextField.topAnchor.constraint(equalTo: messageInputView.topAnchor, constant: 10),
            messageTextField.bottomAnchor.constraint(equalTo: messageInputView.bottomAnchor, constant: -10),
            
            // Voice button constraints
            voiceButton.leadingAnchor.constraint(equalTo: messageTextField.trailingAnchor, constant: 8),
            voiceButton.centerYAnchor.constraint(equalTo: messageTextField.centerYAnchor),
            voiceButton.widthAnchor.constraint(equalToConstant: 40),
            voiceButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Send button constraints
            sendButton.leadingAnchor.constraint(equalTo: voiceButton.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: messageInputView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: messageTextField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 40),
            sendButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Backend status label constraints
            backendStatusLabel.topAnchor.constraint(equalTo: backendStatusView.topAnchor, constant: 8),
            backendStatusLabel.leadingAnchor.constraint(equalTo: backendStatusView.leadingAnchor, constant: 8),
            backendStatusLabel.trailingAnchor.constraint(equalTo: backendStatusView.trailingAnchor, constant: -8),
            backendStatusLabel.bottomAnchor.constraint(equalTo: backendStatusView.bottomAnchor, constant: -8)
        ])
    }
    
    private func setupTableView() {
        tableView.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func setupActions() {
        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
        voiceButton.addTarget(self, action: #selector(activateVoice), for: .touchUpInside)
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func loadMessages() {
        localStorageService.fetchMessages()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error fetching messages: \(error)")
                }
            }, receiveValue: { [weak self] messages in
                self?.messages = messages
                self?.tableView.reloadData()
                self?.scrollToBottom()
            })
            .store(in: &cancellables)
    }
    
    private func checkBackendStatus() {
        networkService.checkBackendStatus()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error checking backend: \(error)")
                }
            }, receiveValue: { [weak self] statuses in
                self?.backendStatus = statuses["unified_backend"] ?? false
                self?.updateBackendStatusDisplay()
            })
            .store(in: &cancellables)
    }
    
    private func updateBackendStatusDisplay() {
        DispatchQueue.main.async { [weak self] in
            let statusEmoji = self?.backendStatus == true ? "🟢" : "🔴"
            let statusText = self?.backendStatus == true ? "Unified Backend Online" : "Backend Offline"
            self?.title = "Chat Assistant \(statusEmoji)"
            
            if self?.backendStatus == false {
                self?.addSystemMessage("⚠️ Unified backend server is offline. Please check connection.")
            }
        }
    }
    
    @objc private func sendMessage() {
        guard let text = messageTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return
        }
        
        // Add user message to chat
        let userMessage = createMessage(content: text, isSenderUser: true)
        saveMessage(userMessage)
        
        // Clear input
        messageTextField.text = ""
        
        // Update UI
        updateChatDisplay()
        
        // Send to backend
        Task {
            do {
                let response = try await NetworkService.shared.sendMessageWithOpenAPI(text)
                
                DispatchQueue.main.async {
                    // Add bot response to chat
                    let botMessage = self.createMessage(content: response.message, isSenderUser: false)
                    self.saveMessage(botMessage)
                    self.updateChatDisplay()
                    
                    // Process the response for actions
                    self.processResponse(response)
                }
            } catch {
                DispatchQueue.main.async {
                    let errorMessage = self.createMessage(content: "Помилка: \(error.localizedDescription)", isSenderUser: false)
                    self.saveMessage(errorMessage)
                    self.updateChatDisplay()
                }
            }
        }
    }
    
    @objc private func activateVoice() {
        guard !isListening else {
            // Stop listening if already active
            voiceService.stopListening()
            isListening = false
            voiceButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
            voiceButton.tintColor = .systemBlue
            return
        }
        
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch authStatus {
                case .authorized:
                    self.startVoiceRecognition()
                case .denied, .restricted, .notDetermined:
                    self.showVoicePermissionAlert()
                @unknown default:
                    self.showVoicePermissionAlert()
                }
            }
        }
    }
    
    private func startVoiceRecognition() {
        isListening = true
        voiceButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        voiceButton.tintColor = .systemRed
        
        voiceService.startListening { [weak self] text, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Voice recognition error: \(error)")
                    self.stopVoiceRecognition()
                    self.showErrorAlert(message: "Помилка розпізнавання голосу: \(error.localizedDescription)")
                    return
                }
                
                if let text = text, !text.isEmpty && text != "Listening..." {
                    // Check for voice commands first
                    if !self.voiceService.processVoiceCommand(text) {
                        // If not a command, use as regular message
                        self.messageTextField.text = text
                        self.stopVoiceRecognition()
                        
                        // Automatically send the message
                        self.sendMessage()
                        
                        // Speak confirmation in detected language
                        let confirmationText = text.contains("а") || text.contains("і") || text.contains("у") ? 
                            "Повідомлення надіслано" : "Message sent"
                        self.voiceService.speakText(confirmationText)
                    }
                }
            }
        }
    }
    
    private func stopVoiceRecognition() {
        isListening = false
        voiceService.stopListening()
        voiceButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        voiceButton.tintColor = .systemBlue
    }
    
    private func showVoicePermissionAlert() {
        let alert = UIAlertController(
            title: "🎤 Дозвіл на мікрофон",
            message: "Для використання голосового введення потрібен доступ до мікрофона. Будь ласка, надайте дозвіл у Налаштуваннях.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Налаштування", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Скасувати", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func createMessage(content: String, isSenderUser: Bool, agentId: String? = nil) -> ChatMessage {
        let context = localStorageService.viewContext
        let message = ChatMessage(context: context)
        message.id = UUID()
        message.content = content
        message.timestamp = Date()
        message.type = isSenderUser ? "user" : "assistant"
        message.isSenderUser = isSenderUser
        message.agentId = agentId
        return message
    }
    
    private func saveMessage(_ message: ChatMessage) {
        localStorageService.saveContext()
        messages.append(message)
        
        tableView.beginUpdates()
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
        tableView.endUpdates()
        
        scrollToBottom()
    }
    
    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func parseAndCreateCalendarEvent(from message: String) {
        // Look for calendar event data in the message
        guard message.contains("CALENDAR_EVENT_DATA:") else { return }
        
        // Extract JSON data between markers
        let components = message.components(separatedBy: "CALENDAR_EVENT_DATA:")
        guard components.count > 1 else { return }
        
        let jsonPart = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let endMarkers = ["---", "\n\n", "💡"]
        var jsonString = jsonPart
        
        for marker in endMarkers {
            if let range = jsonString.range(of: marker) {
                jsonString = String(jsonString[..<range.lowerBound])
                break
            }
        }
        
        // Parse JSON
        guard let jsonData = jsonString.data(using: .utf8),
              let eventData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let action = eventData["action"] as? String,
              action == "create_calendar_event",
              let title = eventData["title"] as? String,
              let timeString = eventData["time"] as? String,
              let dateString = eventData["date"] as? String else {
            print("Failed to parse calendar event data")
            return
        }
        
        // Convert to actual dates
        let startDate = convertToDate(dateString: dateString, timeString: timeString)
        let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
        let location = eventData["location"] as? String
        
        // Create calendar event
        integrationService.createCalendarEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: "Створено AI асистентом CrashCurse"
        ) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.showCalendarSuccessAlert(title: title, date: startDate)
                } else {
                    self?.showCalendarErrorAlert(error: error)
                }
            }
        }
        
        // Also save to local storage
        _ = localStorageService.saveEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            notes: "Створено AI асистентом"
        )
    }
    
    private func convertToDate(dateString: String, timeString: String) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Parse time
        let timeComponents = timeString.split(separator: ":")
        let hour = Int(timeComponents.first ?? "12") ?? 12
        let minute = timeComponents.count > 1 ? Int(timeComponents[1]) ?? 0 : 0
        
        var targetDate: Date
        
        // Parse date
        switch dateString.lowercased() {
        case "сьогодні", "today":
            targetDate = now
        case "завтра", "tomorrow":
            targetDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        default:
            targetDate = now
        }
        
        // Set specific time
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        return calendar.date(from: dateComponents) ?? now
    }
    
    private func showCalendarSuccessAlert(title: String, date: Date) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "uk_UA")
        
        let alert = UIAlertController(
            title: "✅ Подія створена!",
            message: "Зустріч '\(title)' додана в календар на \(formatter.string(from: date))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showCalendarErrorAlert(error: Error?) {
        let message = error?.localizedDescription ?? "Не вдалося створити подію в календарі"
        let alert = UIAlertController(
            title: "❌ Помилка",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func parseAndCreateReminder(from message: String) {
        // Look for reminder data in the message
        guard message.contains("REMINDER_DATA:") else { return }
        
        // Extract JSON data between markers
        let components = message.components(separatedBy: "REMINDER_DATA:")
        guard components.count > 1 else { return }
        
        let jsonPart = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let endMarkers = ["---", "\n\n", "💡"]
        var jsonString = jsonPart
        
        for marker in endMarkers {
            if let range = jsonString.range(of: marker) {
                jsonString = String(jsonString[..<range.lowerBound])
                break
            }
        }
        
        // Parse JSON
        guard let jsonData = jsonString.data(using: .utf8),
              let reminderData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let title = reminderData["title"] as? String,
              let timeString = reminderData["time"] as? String,
              let dateString = reminderData["date"] as? String else {
            print("Failed to parse reminder data")
            return
        }
        
        // Convert to actual dates
        let reminderDate = convertToDate(dateString: dateString, timeString: timeString)
        
        // Create reminder
        integrationService.createReminder(
            title: title,
            date: reminderDate,
            notes: "Створено AI асистентом"
        ) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.showReminderSuccessAlert(title: title, date: reminderDate)
                } else {
                    self?.showReminderErrorAlert(error: error)
                }
            }
        }
        
        // Also save to local storage
        _ = localStorageService.saveReminder(
            title: title,
            date: reminderDate,
            notes: "Створено AI асистентом"
        )
    }
    
    private func showReminderSuccessAlert(title: String, date: Date) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "uk_UA")
        
        let alert = UIAlertController(
            title: "✅ Нагадування створено!",
            message: "Нагадування '\(title)' додано на \(formatter.string(from: date))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showReminderErrorAlert(error: Error?) {
        let message = error?.localizedDescription ?? "Не вдалося створити нагадування"
        let alert = UIAlertController(
            title: "❌ Помилка",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func speakResponse(_ message: String) {
        // Filter out technical data (JSON, markers, etc.) and speak only user-friendly text
        var cleanedMessage = message
        
        // Remove calendar event data block
        if let calendarRange = cleanedMessage.range(of: "CALENDAR_EVENT_DATA:") {
            if let endRange = cleanedMessage.range(of: "---", range: calendarRange.upperBound..<cleanedMessage.endIndex) {
                cleanedMessage.removeSubrange(calendarRange.lowerBound..<endRange.upperBound)
            }
        }
        
        // Remove reminder data block
        if let reminderRange = cleanedMessage.range(of: "REMINDER_DATA:") {
            if let endRange = cleanedMessage.range(of: "---", range: reminderRange.upperBound..<cleanedMessage.endIndex) {
                cleanedMessage.removeSubrange(reminderRange.lowerBound..<endRange.upperBound)
            }
        }
        
        // Remove markdown formatting and emojis for speech
        cleanedMessage = cleanedMessage
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "###", with: "")
            .replacingOccurrences(of: "•", with: "")
            .replacingOccurrences(of: "---", with: "")
        
        // Remove emojis using regex
        let range = NSRange(location: 0, length: cleanedMessage.utf16.count)
        let regex = try! NSRegularExpression(pattern: "[\\p{So}\\p{Cn}]", options: [])
        cleanedMessage = regex.stringByReplacingMatches(in: cleanedMessage, options: [], range: range, withTemplate: "")
        
        // Get the first meaningful sentence or two for speech
        let sentences = cleanedMessage.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let speechText = sentences.prefix(2).joined(separator: ". ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only speak if there's meaningful content and it's not too long
        if !speechText.isEmpty && speechText.count > 10 && speechText.count < 200 {
            voiceService.speakText(speechText)
        }
    }
    
    // MARK: - New Functionality Parsers
    
    private func parseAndDisplayWeather(from message: String) {
        guard message.contains("WEATHER_DATA:") else { return }
        
        let components = message.components(separatedBy: "WEATHER_DATA:")
        guard components.count > 1 else { return }
        
        let jsonPart = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let endMarkers = ["---", "\n\n", "💡"]
        var jsonString = jsonPart
        
        for marker in endMarkers {
            if let range = jsonString.range(of: marker) {
                jsonString = String(jsonString[..<range.lowerBound])
                break
            }
        }
        
        guard let jsonData = jsonString.data(using: .utf8),
              let weatherData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let location = weatherData["location"] as? String else {
            return
        }
        
        // Extract weather details
        let temperature = weatherData["temperature"] as? String ?? "N/A"
        let description = weatherData["description"] as? String ?? "N/A"
        let humidity = weatherData["humidity"] as? String ?? "N/A"
        let feelsLike = weatherData["feels_like"] as? String ?? "N/A"
        let windSpeed = weatherData["wind_speed"] as? String ?? "N/A"
        let isRealData = weatherData["real_data"] as? Bool ?? false
        
        showDetailedWeatherAlert(
            location: location,
            temperature: temperature,
            description: description,
            humidity: humidity,
            feelsLike: feelsLike,
            windSpeed: windSpeed,
            isRealData: isRealData
        )
    }
    
    private func parseAndExecuteContactAction(from message: String) {
        guard message.contains("CONTACT_DATA:") else { return }
        
        let components = message.components(separatedBy: "CONTACT_DATA:")
        guard components.count > 1 else { return }
        
        let jsonPart = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let endMarkers = ["---", "\n\n", "💡"]
        var jsonString = jsonPart
        
        for marker in endMarkers {
            if let range = jsonString.range(of: marker) {
                jsonString = String(jsonString[..<range.lowerBound])
                break
            }
        }
        
        guard let jsonData = jsonString.data(using: .utf8),
              let contactData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let action = contactData["action"] as? String,
              let contactName = contactData["contact_name"] as? String else {
            return
        }
        
        if action == "call" {
            makePhoneCall(to: contactName)
        } else if action == "sms" {
            sendSMS(to: contactName, message: contactData["message"] as? String ?? "")
        }
    }
    
    private func parseAndSaveFinanceData(from message: String) {
        guard message.contains("FINANCE_DATA:") else { return }
        
        let components = message.components(separatedBy: "FINANCE_DATA:")
        guard components.count > 1 else { return }
        
        let jsonPart = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let endMarkers = ["---", "\n\n", "💡"]
        var jsonString = jsonPart
        
        for marker in endMarkers {
            if let range = jsonString.range(of: marker) {
                jsonString = String(jsonString[..<range.lowerBound])
                break
            }
        }
        
        guard let jsonData = jsonString.data(using: .utf8),
              let financeData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let amount = financeData["amount"] as? String,
              let description = financeData["description"] as? String else {
            return
        }
        
        saveExpense(amount: amount, description: description)
    }
    
    private func parseAndCreateShoppingList(from message: String) {
        guard message.contains("SHOPPING_DATA:") else { return }
        
        let components = message.components(separatedBy: "SHOPPING_DATA:")
        guard components.count > 1 else { return }
        
        let jsonPart = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let endMarkers = ["---", "\n\n", "💡"]
        var jsonString = jsonPart
        
        for marker in endMarkers {
            if let range = jsonString.range(of: marker) {
                jsonString = String(jsonString[..<range.lowerBound])
                break
            }
        }
        
        guard let jsonData = jsonString.data(using: .utf8),
              let shoppingData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let items = shoppingData["items"] as? [String] else {
            return
        }
        
        createShoppingReminders(items: items)
    }
    
    // MARK: - Helper Methods for New Functionality
    
    private func showDetailedWeatherAlert(
        location: String,
        temperature: String,
        description: String,
        humidity: String,
        feelsLike: String,
        windSpeed: String,
        isRealData: Bool
    ) {
        let weatherIcon = getWeatherIcon(description: description)

        let weatherDetails = """
        \(weatherIcon) **Погода у місті \(location)**
        
        🌡️ Температура: **\(temperature)** (Відчувається як \(feelsLike))
        ☁️ Опис: \(description)
        💧 Вологість: \(humidity)
        💨 Вітер: \(windSpeed)
        """

        let alert = UIAlertController(title: nil, message: weatherDetails, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func getWeatherIcon(description: String) -> String {
        let desc = description.lowercased()
        
        if desc.contains("сонце") || desc.contains("sunny") || desc.contains("clear") {
            return "☀️"
        } else if desc.contains("хмар") || desc.contains("cloud") {
            return "☁️"
        } else if desc.contains("дощ") || desc.contains("rain") {
            return "🌧️"
        } else if desc.contains("сніг") || desc.contains("snow") {
            return "❄️"
        } else if desc.contains("туман") || desc.contains("fog") || desc.contains("mist") {
            return "🌫️"
        } else if desc.contains("гроза") || desc.contains("thunder") {
            return "⛈️"
        } else {
            return "🌤️"
        }
    }
    
    private func makePhoneCall(to contactName: String) {
        // In a real app, you would search contacts and make actual call
        let alert = UIAlertController(
            title: "📞 Дзвінок",
            message: "Дзвоню \(contactName)...\n\n💡 Для реальних дзвінків інтегруйте ContactsUI framework",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func sendSMS(to contactName: String, message: String) {
        // In a real app, you would use MessageUI framework
        let alert = UIAlertController(
            title: "💬 SMS",
            message: "Надсилаю повідомлення \(contactName): \"\(message)\"\n\n💡 Для реальних SMS інтегруйте MessageUI framework",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func saveExpense(amount: String, description: String) {
        // Save to local storage and show confirmation
        let alert = UIAlertController(
            title: "💰 Витрата збережена",
            message: "Сума: \(amount) грн\nОпис: \(description)\n\n💡 Витрата додана в ваш фінансовий трек!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func createShoppingReminders(items: [String]) {
        // Create individual reminders for each shopping item
        for item in items {
            integrationService.createReminder(
                title: "Купити: \(item)",
                dueDate: nil,
                notes: "Додано AI асистентом CrashCurse"
            ) { success, error in
                // Handle each item creation result if needed
            }
        }
        
        let itemsText = items.joined(separator: ", ")
        let alert = UIAlertController(
            title: "🛒 Список покупок створено",
            message: "Додано в нагадування: \(itemsText)\n\n💡 Перевірте додаток Нагадування на iPhone!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Navigation Handler
    private func handleNavigationRequest(_ response: ChatResponse) -> Bool {
        guard response.isNavigationRequest,
              let destination = response.destination,
              let mapsUrl = response.apple_maps_url ?? response.maps_scheme_url else {
            print("❌ Navigation request missing required data")
            return false
        }
        
        print("🗺️ Processing navigation request:")
        print("   Destination: \(destination)")
        print("   Transport: \(response.transport_mode ?? "N/A")")
        print("   URL: \(mapsUrl)")
        
        // Try to open the maps URL
        if let url = URL(string: mapsUrl), UIApplication.shared.canOpenURL(url) {
            let alert = UIAlertController(
                title: "🗺️ Відкрити навігацію?",
                message: "Прокласти маршрут до \(destination) в Apple Maps?\n\nТранспорт: \(response.transport_mode ?? "автомобіль")",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Відкрити Maps", style: .default) { _ in
                UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        print("✅ Successfully opened Apple Maps")
                    } else {
                        print("❌ Failed to open Apple Maps")
                        self.showNavigationFallback(destination: destination, mapsUrl: mapsUrl)
                    }
                }
            })
            
            alert.addAction(UIAlertAction(title: "Скасувати", style: .cancel))
            present(alert, animated: true)
            
        } else {
            print("❌ Cannot open maps URL: \(mapsUrl)")
            showNavigationFallback(destination: destination, mapsUrl: mapsUrl)
        }
        
        return true
    }
    
    private func showNavigationFallback(destination: String, mapsUrl: String) {
        let alert = UIAlertController(
            title: "🗺️ Навігація",
            message: "Маршрут до \(destination) готовий!\n\nURL: \(mapsUrl)\n\n💡 Скопіюйте посилання для використання в браузері або іншому навігаційному додатку.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Копіювати URL", style: .default) { _ in
            UIPasteboard.general.string = mapsUrl
            
            let confirmAlert = UIAlertController(
                title: "✅ Скопійовано",
                message: "URL навігації скопійовано в буфер обміну",
                preferredStyle: .alert
            )
            confirmAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(confirmAlert, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func processResponse(_ response: ChatResponse) {
        // Process in order of priority
        
        // 1. Navigation requests (highest priority)
        if handleNavigationRequest(response) {
            return
        }
        
        // 2. Parse and create calendar events from message content
        parseAndCreateCalendarEvent(from: response.message)
        
        // 3. Parse and create reminders from message content
        parseAndCreateReminder(from: response.message)
        
        // 4. Weather requests
        if handleWeatherRequest(response) {
            return
        }
        
        // 5. OpenAPI requests
        if handleOpenAPIRequest(response) {
            return
        }
        
        // 6. Calendar requests
        if handleCalendarRequest(response) {
            return
        }
        
        // 7. Reminder requests
        if handleReminderRequest(response) {
            return
        }
        
        // 8. Default: just show the message
        showSimpleAlert(title: "Відповідь", message: response.message)
    }
    
    // MARK: - Additional Response Handlers
    private func handleWeatherRequest(_ response: ChatResponse) -> Bool {
        guard response.isWeatherRequest else { return false }
        
        if let location = response.location,
           let temperature = response.temperature,
           let description = response.description {
            showDetailedWeatherAlert(
                location: location,
                temperature: temperature,
                description: description,
                humidity: response.humidity ?? "N/A",
                feelsLike: response.feels_like ?? "N/A",
                windSpeed: response.wind_speed ?? "N/A",
                isRealData: response.is_real_data ?? false
            )
            return true
        }
        
        return false
    }
    
    private func handleCalendarRequest(_ response: ChatResponse) -> Bool {
        guard response.calendar == true else { return false }
        
        if let title = response.event_title,
           let date = response.event_date,
           let time = response.event_time {
            
            let message = "📅 Створено подію:\n\n📝 \(title)\n📅 \(date)\n⏰ \(time)"
            if let location = response.event_location {
                showSimpleAlert(title: "Календар", message: message + "\n📍 \(location)")
            } else {
                showSimpleAlert(title: "Календар", message: message)
            }
            return true
        }
        
        return false
    }
    
    private func handleReminderRequest(_ response: ChatResponse) -> Bool {
        guard response.reminder == true else { return false }
        
        if let reminderText = response.reminder_text,
           let reminderTime = response.reminder_time {
            
            let message = "⏰ Створено нагадування:\n\n📝 \(reminderText)\n⏰ \(reminderTime)"
            showSimpleAlert(title: "Нагадування", message: message)
            return true
        }
        
        return false
    }
    
    private func handleOpenAPIRequest(_ response: ChatResponse) -> Bool {
        guard response.isAPIRequest else { return false }
        
        let title = "API Відповідь"
        var message = response.message
        
        // Add API status if available
        if let apiStatus = response.api_status {
            message += "\n\n📡 **Статус API:** \(apiStatus)"
        }
        
        // Add agent info if available
        if let agentUsed = response.agent_used {
            message += "\n🤖 **Агент:** \(agentUsed)"
        }
        
        // If there's structured API response data, show it formatted
        if let apiResponse = response.api_response {
            message += "\n\n📋 **Дані API:**"
            message += formatAPIResponse(apiResponse)
        }
        
        showDetailedAPIAlert(title: title, message: message, apiData: response.api_response)
        return true
    }
    
    private func formatAPIResponse(_ apiResponse: [String: AnyCodable]) -> String {
        var formatted = ""
        
        for (key, value) in apiResponse {
            switch key.lowercased() {
            case "weather", "погода":
                formatted += "\n🌤️ **\(key):** \(formatValue(value.value))"
            case "news", "новини":
                formatted += "\n📰 **\(key):** \(formatValue(value.value))"
            case "rates", "курси":
                formatted += "\n💱 **\(key):** \(formatValue(value.value))"
            case "status":
                formatted += "\n📊 **\(key):** \(formatValue(value.value))"
            default:
                formatted += "\n📋 **\(key):** \(formatValue(value.value))"
            }
        }
        
        return formatted
    }
    
    private func formatValue(_ value: Any) -> String {
        if let string = value as? String {
            return string
        } else if let number = value as? NSNumber {
            return number.stringValue
        } else if let dict = value as? [String: Any] {
            return dict.description
        } else if let array = value as? [Any] {
            return array.description
        } else {
            return String(describing: value)
        }
    }
    
    private func showDetailedAPIAlert(title: String, message: String, apiData: [String: AnyCodable]?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // Add action to view raw API data if available
        if let apiData = apiData {
            alert.addAction(UIAlertAction(title: "Показати сирі дані", style: .default) { _ in
                self.showRawAPIData(apiData)
            })
        }
        
        // Add action to call custom API
        alert.addAction(UIAlertAction(title: "Викликати API", style: .default) { _ in
            self.showCustomAPIDialog()
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
    
    private func showRawAPIData(_ apiData: [String: AnyCodable]) {
        let jsonString = formatAPIDataAsJSON(apiData)
        
        let alert = UIAlertController(title: "Сирі дані API", message: jsonString, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Скопіювати", style: .default) { _ in
            UIPasteboard.general.string = jsonString
            self.showSimpleAlert(title: "Скопійовано", message: "Дані скопійовано в буфер обміну")
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
    
    private func formatAPIDataAsJSON(_ apiData: [String: AnyCodable]) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: apiData.mapValues { $0.value }, options: .prettyPrinted)
            return String(data: data, encoding: .utf8) ?? "Помилка форматування"
        } catch {
            return "Помилка: \(error.localizedDescription)"
        }
    }
    
    private func showCustomAPIDialog() {
        let alert = UIAlertController(title: "Викликати власний API", message: "Введіть URL та параметри", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "URL (наприклад: https://api.example.com/data)"
            textField.keyboardType = .URL
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Метод (GET, POST, PUT, DELETE)"
            textField.text = "GET"
        }
        
        alert.addAction(UIAlertAction(title: "Викликати", style: .default) { _ in
            guard let urlField = alert.textFields?[0],
                  let methodField = alert.textFields?[1],
                  let url = urlField.text, !url.isEmpty,
                  let method = methodField.text, !method.isEmpty else {
                self.showSimpleAlert(title: "Помилка", message: "Заповніть всі поля")
                return
            }
            
            self.callCustomAPI(url: url, method: method)
        })
        
        alert.addAction(UIAlertAction(title: "Скасувати", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func callCustomAPI(url: String, method: String) {
        Task {
            do {
                let response = try await NetworkService.shared.callOpenAPI(url: url, method: method)
                
                DispatchQueue.main.async {
                    let message = """
                    🔗 **URL:** \(url)
                    📋 **Метод:** \(method)
                    📊 **Статус:** \(response.statusCode)
                    ✅ **Успіх:** \(response.success ? "Так" : "Ні")
                    
                    📄 **Відповідь:**
                    \(response.dictionary?.description ?? "Немає даних")
                    """
                    
                    self.showDetailedAPIAlert(title: "API Відповідь", message: message, apiData: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showSimpleAlert(title: "Помилка API", message: error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Missing Helper Methods
    private func addSystemMessage(_ message: String) {
        let systemMessage = createMessage(content: message, isSenderUser: false)
        saveMessage(systemMessage)
    }
    
    private func updateChatDisplay() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
            self?.scrollToBottom()
        }
    }
    
    private func showSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as? MessageCell else {
            return UITableViewCell()
        }
        
        let message = messages[indexPath.row]
        cell.configure(with: message)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ChatViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - Message Cell
class MessageCell: UITableViewCell {
    private let bubbleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .systemGray
        return label
    }()
    
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var widthConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        bubbleView.addSubview(timestampLabel)
        
        // Create constraints
        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        widthConstraint = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75)
        
        // Add constraints that don't change with message type
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            widthConstraint,
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            
            timestampLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            timestampLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            timestampLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -4)
        ])
    }
    
    func configure(with message: ChatMessage) {
        messageLabel.text = message.content
        
        if let timestamp = message.timestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            timestampLabel.text = formatter.string(from: timestamp)
        } else {
            timestampLabel.text = ""
        }
        
        // Deactivate all position constraints first
        leadingConstraint.isActive = false
        trailingConstraint.isActive = false
        
        // Configure appearance based on sender
        if message.isSenderUser {
            bubbleView.backgroundColor = .systemBlue
            messageLabel.textColor = .white
            timestampLabel.textColor = .white.withAlphaComponent(0.7)
            
            // User messages: align to right
            trailingConstraint.isActive = true
        } else {
            bubbleView.backgroundColor = .systemGray5
            messageLabel.textColor = .label
            timestampLabel.textColor = .systemGray
            
            // Assistant messages: align to left
            leadingConstraint.isActive = true
        }
    }
} 