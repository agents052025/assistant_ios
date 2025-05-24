import Foundation
import Speech
import AVFoundation

class VoiceService: NSObject, SFSpeechRecognizerDelegate {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Support multiple languages
    private var currentLanguage: String = "uk-UA" // Default to Ukrainian
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguage))
        speechRecognizer?.delegate = self
    }
    
    func setLanguage(_ languageCode: String) {
        currentLanguage = languageCode
        setupSpeechRecognizer()
    }
    
    func getCurrentLanguage() -> String {
        return currentLanguage
    }

    func startListening(completion: @escaping (String?, Error?) -> Void) {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            completion(nil, error)
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false

            if let result = result {
                completion(result.bestTranscription.formattedString, nil)
                isFinal = result.isFinal
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                if error != nil {
                    completion(nil, error)
                }
            }
        }

        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            completion(nil, error)
            return
        }
        completion("Listening...", nil)
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
    }
    
    // This function would typically be called by the NetworkService or a similar handler after getting audio data from backend for Text-to-Speech
    func processVoiceInput(_ audioData: Data) {
        // Implementation for Text-to-Speech (e.g., using AVSpeechSynthesizer)
        // This is a placeholder, actual implementation depends on how TTS is handled (device or server-side)
        
        // For example, if the server sends back text to be spoken:
        // if let textToSpeak = String(data: audioData, encoding: .utf8) {
        //     let utterance = AVSpeechUtterance(string: textToSpeak)
        //     utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        //     let synthesizer = AVSpeechSynthesizer()
        //     synthesizer.speak(utterance)
        // }
    }
    
    // Text-to-Speech function for speaking responses with auto language detection
    func speakText(_ text: String, language: String? = nil) {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        
        // Auto-detect language if not specified
        let detectedLanguage = language ?? detectLanguage(from: text)
        
        utterance.voice = AVSpeechSynthesisVoice(language: detectedLanguage)
        utterance.rate = 0.5
        
        // Adjust voice settings for Ukrainian
        if detectedLanguage.starts(with: "uk") {
            utterance.rate = 0.45 // Slightly slower for Ukrainian pronunciation
            utterance.pitchMultiplier = 1.1
        }
        
        synthesizer.speak(utterance)
    }
    
    // Simple language detection based on text content
    private func detectLanguage(from text: String) -> String {
        let ukrainianChars = CharacterSet(charactersIn: "абвгґдеєжзиіїйклмнопрстуфхцчшщьюяыъэё")
        let textSet = CharacterSet(charactersIn: text.lowercased())
        
        if !ukrainianChars.intersection(textSet).isEmpty {
            return "uk-UA"
        }
        return "en-US"
    }
    
    // Smart voice command processing
    func processVoiceCommand(_ text: String) -> Bool {
        let command = text.lowercased()
        
        // Voice shortcuts for common actions
        if command.contains("зупинити") || command.contains("stop") {
            stopListening()
            return true
        }
        
        if command.contains("змінити мову") || command.contains("change language") {
            toggleLanguage()
            return true
        }
        
        if command.contains("говори українською") {
            setLanguage("uk-UA")
            speakText("Перемикаюся на українську мову", language: "uk-UA")
            return true
        }
        
        if command.contains("speak english") {
            setLanguage("en-US") 
            speakText("Switching to English", language: "en-US")
            return true
        }
        
        return false
    }
    
    private func toggleLanguage() {
        if currentLanguage == "uk-UA" {
            setLanguage("en-US")
            speakText("Language switched to English", language: "en-US")
        } else {
            setLanguage("uk-UA")
            speakText("Мову змінено на українську", language: "uk-UA")
        }
    }

    // SFSpeechRecognizerDelegate method
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            // Speech recognition is available
            print("Speech recognition available")
        } else {
            // Speech recognition not available
            print("Speech recognition not available")
            // Potentially disable voice input features
        }
    }
} 