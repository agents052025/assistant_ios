import UIKit
import AVFoundation
import Speech
import Combine

class VoiceViewController: UIViewController {
    private let voiceService = VoiceService()
    private let networkService = NetworkService()
    private var cancellables = Set<AnyCancellable>()
    private var isListening = false
    
    // UI Components
    private let transcriptionTextView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.layer.borderColor = UIColor.systemGray5.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.backgroundColor = .systemBackground
        return textView
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Натисніть кнопку мікрофона для голосового вводу"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemGray
        label.numberOfLines = 2
        return label
    }()
    
    private let recordButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "mic.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.contentVerticalAlignment = .fill
        button.contentHorizontalAlignment = .fill
        return button
    }()
    
    // Audio level indicator
    private let audioLevelView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray5
        view.layer.cornerRadius = 4
        view.isHidden = true
        return view
    }()
    
    private let audioLevelIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 2
        return view
    }()
    
    private let clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Очистити", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.tintColor = .systemRed
        return button
    }()
    
    private let voiceSettingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Налаштування голосу", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.setImage(UIImage(systemName: "gear"), for: .normal)
        return button
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // Smart listening controls
    private let smartModeSwitch: UISwitch = {
        let switchControl = UISwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.isOn = true
        return switchControl
    }()
    
    private let smartModeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Розумний режим"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemGray
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        setupVoiceService()
        requestSpeechRecognitionPermission()
        title = "🎤 Голосовий асистент"
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(transcriptionTextView)
        view.addSubview(statusLabel)
        view.addSubview(recordButton)
        view.addSubview(audioLevelView)
        view.addSubview(clearButton)
        view.addSubview(voiceSettingsButton)
        view.addSubview(activityIndicator)
        view.addSubview(smartModeSwitch)
        view.addSubview(smartModeLabel)
        
        // Audio level setup
        audioLevelView.addSubview(audioLevelIndicator)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Transcription text view
            transcriptionTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            transcriptionTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            transcriptionTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            transcriptionTextView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.3),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: transcriptionTextView.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Smart mode controls
            smartModeLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            smartModeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            smartModeSwitch.centerYAnchor.constraint(equalTo: smartModeLabel.centerYAnchor),
            smartModeSwitch.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Record button
            recordButton.topAnchor.constraint(equalTo: smartModeSwitch.bottomAnchor, constant: 20),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 80),
            recordButton.heightAnchor.constraint(equalToConstant: 80),
            
            // Audio level indicator
            audioLevelView.topAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: 12),
            audioLevelView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            audioLevelView.widthAnchor.constraint(equalToConstant: 200),
            audioLevelView.heightAnchor.constraint(equalToConstant: 8),
            
            audioLevelIndicator.leadingAnchor.constraint(equalTo: audioLevelView.leadingAnchor),
            audioLevelIndicator.topAnchor.constraint(equalTo: audioLevelView.topAnchor),
            audioLevelIndicator.bottomAnchor.constraint(equalTo: audioLevelView.bottomAnchor),
            audioLevelIndicator.widthAnchor.constraint(equalToConstant: 10),
            
            // Clear button
            clearButton.topAnchor.constraint(equalTo: audioLevelView.bottomAnchor, constant: 20),
            clearButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Voice settings button
            voiceSettingsButton.topAnchor.constraint(equalTo: clearButton.bottomAnchor, constant: 12),
            voiceSettingsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: voiceSettingsButton.bottomAnchor, constant: 20)
        ])
    }
    
    private func setupActions() {
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        voiceSettingsButton.addTarget(self, action: #selector(voiceSettingsButtonTapped), for: .touchUpInside)
        smartModeSwitch.addTarget(self, action: #selector(smartModeSwitchChanged), for: .valueChanged)
    }
    
    private func setupVoiceService() {
        // Configure callbacks
        voiceService.onTranscriptionUpdate = { [weak self] text in
            self?.updateTranscription(text)
        }
        
        voiceService.onSpeechComplete = { [weak self] text in
            self?.handleSpeechComplete(text)
        }
        
        voiceService.onError = { [weak self] error in
            self?.handleVoiceError(error)
        }
        
        voiceService.onAudioLevelUpdate = { [weak self] level in
            self?.updateAudioLevel(level)
        }
        
        // Configure ElevenLabs API key (you should set this in app configuration)
        // voiceService.setElevenLabsAPIKey("YOUR_API_KEY")
    }
    
    private func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] (authStatus: SFSpeechRecognizerAuthorizationStatus) in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.recordButton.isEnabled = true
                    self?.statusLabel.text = "Готовий до голосового вводу"
                case .denied:
                    self?.recordButton.isEnabled = false
                    self?.statusLabel.text = "Голосове розпізнавання відхилено в налаштуваннях"
                case .restricted:
                    self?.recordButton.isEnabled = false
                    self?.statusLabel.text = "Голосове розпізнавання обмежено на цьому пристрої"
                case .notDetermined:
                    self?.recordButton.isEnabled = false
                    self?.statusLabel.text = "Голосове розпізнавання ще не авторизовано"
                @unknown default:
                    self?.recordButton.isEnabled = false
                    self?.statusLabel.text = "Невідомий статус голосового розпізнавання"
                }
            }
        }
    }
    
    // MARK: - Actions
    @objc private func recordButtonTapped() {
        if isListening {
            stopVoiceRecognition()
        } else {
            startVoiceRecognition()
        }
    }
    
    @objc private func clearButtonTapped() {
        transcriptionTextView.text = ""
        statusLabel.text = "Готовий до голосового вводу"
    }
    
    @objc private func voiceSettingsButtonTapped() {
        showVoiceSettings()
    }
    
    @objc private func smartModeSwitchChanged() {
        let threshold = smartModeSwitch.isOn ? 1.5 : 5.0
        voiceService.setSilenceThreshold(threshold)
        
        statusLabel.text = smartModeSwitch.isOn ? 
            "Розумний режим: автоматичне визначення завершення" : 
            "Звичайний режим: ручне керування"
    }
    
    // MARK: - Voice Recognition
    private func startVoiceRecognition() {
        guard !isListening else { return }
        
        isListening = true
        audioLevelView.isHidden = false
        updateRecordButtonState()
        
        if smartModeSwitch.isOn {
            statusLabel.text = "🎤 Слухаю... Говоріть природно"
            voiceService.startSmartListening()
        } else {
            statusLabel.text = "🎤 Запис... Натисніть знову для зупинки"
            voiceService.startSmartListening() // Use same method but different UI feedback
        }
    }
    
    private func stopVoiceRecognition() {
        guard isListening else { return }
        
        voiceService.stopListening()
        isListening = false
        audioLevelView.isHidden = true
        updateRecordButtonState()
        statusLabel.text = "Обробка голосового запиту..."
    }
    
    private func updateRecordButtonState() {
        UIView.animate(withDuration: 0.3) {
            if self.isListening {
                self.recordButton.tintColor = .systemRed
                self.recordButton.setImage(UIImage(systemName: self.smartModeSwitch.isOn ? "waveform.circle.fill" : "stop.circle.fill"), for: .normal)
                self.recordButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            } else {
                self.recordButton.tintColor = .systemBlue
                self.recordButton.setImage(UIImage(systemName: "mic.circle.fill"), for: .normal)
                self.recordButton.transform = .identity
            }
        }
    }
    
    // MARK: - Voice Service Callbacks
    private func updateTranscription(_ text: String) {
        transcriptionTextView.text = text
        
        if text == "🎤 Listening..." {
            transcriptionTextView.textColor = .systemGray
        } else {
            transcriptionTextView.textColor = .label
        }
        
        // Auto-scroll to bottom
        let bottom = NSMakeRange(transcriptionTextView.text.count - 1, 1)
        transcriptionTextView.scrollRangeToVisible(bottom)
    }
    
    private func handleSpeechComplete(_ text: String) {
        stopVoiceRecognition()
        
        guard !text.isEmpty && text != "🎤 Listening..." else {
            statusLabel.text = "Голосовий запит порожній. Спробуйте ще раз."
            return
        }
        
        statusLabel.text = "Надсилання запиту до AI..."
        activityIndicator.startAnimating()
        
        // Send to backend
        sendMessageToAI(text)
    }
    
    private func handleVoiceError(_ error: Error) {
        stopVoiceRecognition()
        showAlert(title: "Помилка голосового розпізнавання", message: error.localizedDescription)
    }
    
    private func updateAudioLevel(_ level: Float) {
        // Convert dB to visual scale (0-1)
        let normalizedLevel = max(0, min(1, (level + 50) / 50)) // Assuming -50dB to 0dB range
        
        UIView.animate(withDuration: 0.1) {
            self.audioLevelIndicator.transform = CGAffineTransform(scaleX: normalizedLevel * 20, y: 1.0)
            
            // Color coding based on level
            if normalizedLevel > 0.7 {
                self.audioLevelIndicator.backgroundColor = .systemRed
            } else if normalizedLevel > 0.3 {
                self.audioLevelIndicator.backgroundColor = .systemOrange
            } else {
                self.audioLevelIndicator.backgroundColor = .systemGreen
            }
        }
    }
    
    // MARK: - AI Integration
    private func sendMessageToAI(_ text: String) {
        networkService.sendMessage(text)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.activityIndicator.stopAnimating()
                    if case .failure(let error) = completion {
                        self?.showAlert(title: "Помилка мережі", message: "Не вдалося надіслати повідомлення: \(error.localizedDescription)")
                        self?.statusLabel.text = "Помилка надсилання. Спробуйте ще раз."
                    }
                },
                receiveValue: { [weak self] response in
                    self?.handleAIResponse(response)
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleAIResponse(_ response: ChatResponse) {
        statusLabel.text = "Відповідь отримана. Програвання..."
        
        // Speak response using ElevenLabs
        voiceService.speakWithElevenLabs(response.message) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.statusLabel.text = "✅ Готовий до нового запиту"
                } else {
                    self?.statusLabel.text = "⚠️ Відповідь програна. Готовий до нового запиту"
                }
            }
        }
        
        // Show response in transcription area
        let fullConversation = "\n\n👤 Ви: \(transcriptionTextView.text ?? "")\n\n🤖 Асистент: \(response.message)"
        transcriptionTextView.text = fullConversation
        transcriptionTextView.textColor = .label
    }
    
    // MARK: - Voice Settings
    private func showVoiceSettings() {
        let alert = UIAlertController(title: "Налаштування голосу", message: "Виберіть налаштування", preferredStyle: .actionSheet)
        
        // Language settings
        alert.addAction(UIAlertAction(title: "Українська мова", style: .default) { _ in
            self.voiceService.setLanguage("uk-UA")
            self.showAlert(title: "✅", message: "Встановлено українську мову")
        })
        
        alert.addAction(UIAlertAction(title: "English", style: .default) { _ in
            self.voiceService.setLanguage("en-US")
            self.showAlert(title: "✅", message: "Language set to English")
        })
        
        // Silence threshold settings
        alert.addAction(UIAlertAction(title: "Швидкий режим (1с тиші)", style: .default) { _ in
            self.voiceService.setSilenceThreshold(1.0)
            self.showAlert(title: "✅", message: "Встановлено швидкий режим")
        })
        
        alert.addAction(UIAlertAction(title: "Стандартний режим (1.5с тиші)", style: .default) { _ in
            self.voiceService.setSilenceThreshold(1.5)
            self.showAlert(title: "✅", message: "Встановлено стандартний режим")
        })
        
        alert.addAction(UIAlertAction(title: "Повільний режим (3с тиші)", style: .default) { _ in
            self.voiceService.setSilenceThreshold(3.0)
            self.showAlert(title: "✅", message: "Встановлено повільний режим")
        })
        
        // ElevenLabs voices (if configured)
        alert.addAction(UIAlertAction(title: "Голоси ElevenLabs", style: .default) { _ in
            self.loadElevenLabsVoices()
        })
        
        alert.addAction(UIAlertAction(title: "Скасувати", style: .cancel))
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = voiceSettingsButton
            popover.sourceRect = voiceSettingsButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func loadElevenLabsVoices() {
        activityIndicator.startAnimating()
        
        voiceService.getAvailableElevenLabsVoices()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.activityIndicator.stopAnimating()
                    if case .failure(let error) = completion {
                        self?.showAlert(title: "Помилка", message: "Не вдалося завантажити голоси: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] voices in
                    self?.showVoiceSelectionAlert(voices: voices)
                }
            )
            .store(in: &cancellables)
    }
    
    private func showVoiceSelectionAlert(voices: [ElevenLabsVoice]) {
        let alert = UIAlertController(title: "Виберіть голос", message: "Доступні голоси ElevenLabs", preferredStyle: .actionSheet)
        
        for voice in voices.prefix(10) { // Limit to first 10 voices
            alert.addAction(UIAlertAction(title: "\(voice.name) (\(voice.category))", style: .default) { _ in
                self.voiceService.setElevenLabsVoice(voice.voice_id)
                self.showAlert(title: "✅", message: "Встановлено голос: \(voice.name)")
            })
        }
        
        alert.addAction(UIAlertAction(title: "Скасувати", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = voiceSettingsButton
            popover.sourceRect = voiceSettingsButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 