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
        return textView
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Tap the button to start speaking"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemGray
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
    
    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Send", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 20
        button.isEnabled = false
        return button
    }()
    
    private let clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Clear", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.tintColor = .systemRed
        return button
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        requestSpeechRecognitionPermission()
        title = "Voice Assistant"
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(transcriptionTextView)
        view.addSubview(statusLabel)
        view.addSubview(recordButton)
        view.addSubview(sendButton)
        view.addSubview(clearButton)
        view.addSubview(activityIndicator)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Transcription text view
            transcriptionTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            transcriptionTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            transcriptionTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            transcriptionTextView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: transcriptionTextView.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Record button
            recordButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 80),
            recordButton.heightAnchor.constraint(equalToConstant: 80),
            
            // Send button
            sendButton.topAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: 20),
            sendButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 120),
            sendButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Clear button
            clearButton.topAnchor.constraint(equalTo: sendButton.bottomAnchor, constant: 12),
            clearButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: clearButton.bottomAnchor, constant: 20)
        ])
    }
    
    private func setupActions() {
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
    }
    
    private func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] (authStatus: SFSpeechRecognizerAuthorizationStatus) in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.recordButton.isEnabled = true
                    self?.statusLabel.text = "Tap the button to start speaking"
                case .denied:
                    self?.recordButton.isEnabled = false
                    self?.statusLabel.text = "Speech recognition denied in settings"
                case .restricted:
                    self?.recordButton.isEnabled = false
                    self?.statusLabel.text = "Speech recognition restricted on this device"
                case .notDetermined:
                    self?.recordButton.isEnabled = false
                    self?.statusLabel.text = "Speech recognition not yet authorized"
                @unknown default:
                    self?.recordButton.isEnabled = false
                    self?.statusLabel.text = "Speech recognition status unknown"
                }
            }
        }
    }
    
    @objc private func recordButtonTapped() {
        if isListening {
            // Stop listening
            stopVoiceRecognition()
        } else {
            // Start listening
            startVoiceRecognition()
        }
    }
    
    @objc private func sendButtonTapped() {
        guard let text = transcriptionTextView.text, !text.isEmpty else { return }
        
        sendButton.isEnabled = false
        activityIndicator.startAnimating()
        
        // Send the transcribed text to the network service
        networkService.sendMessage(text)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.activityIndicator.stopAnimating()
                if case .failure(let error) = completion {
                    self?.showAlert(title: "Error", message: "Failed to send message: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] response in
                self?.handleResponse(response)
                self?.sendButton.isEnabled = true
            })
            .store(in: &cancellables)
    }
    
    @objc private func clearButtonTapped() {
        transcriptionTextView.text = ""
        sendButton.isEnabled = false
    }
    
    private func startVoiceRecognition() {
        voiceService.startListening { [weak self] recognizedText, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "Error", message: "Recognition error: \(error.localizedDescription)")
                    self?.stopVoiceRecognition()
                    return
                }
                
                if let text = recognizedText {
                    self?.transcriptionTextView.text = text
                    self?.sendButton.isEnabled = !text.isEmpty && text != "Listening..."
                }
            }
        }
        
        isListening = true
        updateRecordButtonState()
        statusLabel.text = "Listening..."
    }
    
    private func stopVoiceRecognition() {
        voiceService.stopListening()
        isListening = false
        updateRecordButtonState()
        statusLabel.text = "Tap the button to start speaking"
    }
    
    private func updateRecordButtonState() {
        UIView.animate(withDuration: 0.3) {
            if self.isListening {
                self.recordButton.tintColor = .systemRed
                self.recordButton.setImage(UIImage(systemName: "stop.circle.fill"), for: .normal)
            } else {
                self.recordButton.tintColor = .systemBlue
                self.recordButton.setImage(UIImage(systemName: "mic.circle.fill"), for: .normal)
            }
        }
    }
    
    private func handleResponse(_ response: ChatResponse) {
        // Speak the response using text-to-speech
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: response.message)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
        
        // Show response in a pop-up
        showAlert(title: "Assistant Response", message: response.message)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 