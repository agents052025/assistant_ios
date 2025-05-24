import Foundation
import Speech
import AVFoundation
import Combine

// MARK: - ElevenLabs Models
struct ElevenLabsVoiceRequest: Codable {
    let text: String
    let model_id: String
    let voice_settings: VoiceSettings
    
    struct VoiceSettings: Codable {
        let stability: Double
        let similarity_boost: Double
        let style: Double
        let use_speaker_boost: Bool
    }
}

struct ElevenLabsVoice: Codable {
    let voice_id: String
    let name: String
    let preview_url: String?
    let category: String
}

// MARK: - Enhanced Voice Service
class VoiceService: NSObject, SFSpeechRecognizerDelegate, AVAudioPlayerDelegate {
    
    // MARK: - Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioPlayer: AVAudioPlayer?
    
    // ElevenLabs Configuration
    private var elevenLabsAPIKey = AppConfiguration.API.elevenLabsAPIKey
    private let elevenLabsBaseURL = AppConfiguration.API.elevenLabsBaseURL
    private var selectedVoiceId = AppConfiguration.Voice.defaultVoiceId
    
    // Speech Recognition Settings
    private var currentLanguage: String = AppConfiguration.Voice.defaultLanguage
    private var silenceThreshold: Double = AppConfiguration.Voice.silenceThreshold
    private var lastSpeechTime: Date?
    private var silenceTimer: Timer?
    private var isAutoListening = false
    
    // Audio Processing
    private var audioLevelMeter: Float = 0.0
    private let minimumAudioLevel: Float = AppConfiguration.Voice.minimumAudioLevel
    
    // Combine
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    var onTranscriptionUpdate: ((String) -> Void)?
    var onSpeechComplete: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    var onAudioLevelUpdate: ((Float) -> Void)?
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        setupAudioSession()
        
        // Log configuration status
        if AppConfiguration.Debug.enableVoiceLogging {
            AppConfiguration.logConfigurationStatus()
            print("🎤 VoiceService initialized with:")
            print("   Language: \(currentLanguage)")
            print("   Voice ID: \(selectedVoiceId)")
            print("   Silence threshold: \(silenceThreshold)s")
            print("   ElevenLabs: \(isElevenLabsConfigured ? "✅" : "❌")")
        }
    }
    
    // MARK: - Setup Methods
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguage))
        speechRecognizer?.delegate = self
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("❌ Audio session setup failed: \(error)")
        }
    }
    
    // MARK: - Voice Configuration
    func setLanguage(_ languageCode: String) {
        currentLanguage = languageCode
        setupSpeechRecognizer()
        
        // Auto-select appropriate voice for language
        selectedVoiceId = AppConfiguration.voiceId(for: languageCode)
        
        if AppConfiguration.Debug.enableVoiceLogging {
            print("🌍 Language changed to: \(languageCode), Voice: \(selectedVoiceId)")
        }
    }
    
    func setElevenLabsVoice(_ voiceId: String) {
        selectedVoiceId = voiceId
        
        if AppConfiguration.Debug.enableVoiceLogging {
            print("🔊 ElevenLabs voice changed to: \(voiceId)")
        }
    }
    
    func setElevenLabsAPIKey(_ apiKey: String) {
        elevenLabsAPIKey = apiKey
        
        if AppConfiguration.Debug.enableVoiceLogging {
            print("🔑 ElevenLabs API key updated")
        }
    }
    
    func setSilenceThreshold(_ threshold: Double) {
        silenceThreshold = threshold
        
        if AppConfiguration.Debug.enableVoiceLogging {
            print("⏱️ Silence threshold set to: \(threshold)s")
        }
    }
    
    // Check if ElevenLabs is configured
    var isElevenLabsConfigured: Bool {
        return !elevenLabsAPIKey.isEmpty && elevenLabsAPIKey != "YOUR_ELEVENLABS_API_KEY"
    }
    
    // MARK: - Speech Recognition with Auto-Stop
    func startSmartListening() {
        print("🎤 Starting smart voice recognition...")
        isAutoListening = true
        
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onError?(error)
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            let error = NSError(domain: "VoiceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
            onError?(error)
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        
        // Enhanced recognition task with smart stopping
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.onTranscriptionUpdate?(transcription)
                }
                
                // Update last speech time
                self.lastSpeechTime = Date()
                
                // Reset silence timer
                self.resetSilenceTimer()
                
                // Check if speech seems complete (punctuation + pause)
                if result.isFinal || self.isStatementComplete(transcription) {
                    self.completeSpeechRecognition(with: transcription)
                }
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.onError?(error)
                }
                self.stopListening()
            }
        }

        // Setup audio input with level monitoring
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, when in
            self?.recognitionRequest?.append(buffer)
            
            // Monitor audio levels for silence detection
            self?.processAudioBuffer(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            lastSpeechTime = Date()
            resetSilenceTimer()
            
            DispatchQueue.main.async {
                self.onTranscriptionUpdate?("🎤 Listening...")
            }
        } catch {
            onError?(error)
        }
    }
    
    // MARK: - Audio Level Processing
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS (Root Mean Square) for audio level
        var rms: Float = 0
        for i in 0..<frameLength {
            rms += channelData[i] * channelData[i]
        }
        rms = sqrt(rms / Float(frameLength))
        
        // Convert to decibels
        let db = 20 * log10(rms)
        audioLevelMeter = db
        
        DispatchQueue.main.async {
            self.onAudioLevelUpdate?(db)
        }
        
        // Check if audio level indicates speech
        if db > minimumAudioLevel {
            lastSpeechTime = Date()
        }
    }
    
    // MARK: - Smart Speech Completion Detection
    private func isStatementComplete(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ukrainian sentence endings
        let ukrainianEndings = [".", "!", "?", ":", "—"]
        let englishEndings = [".", "!", "?", ":", "—"]
        
        let endings = currentLanguage.starts(with: "uk") ? ukrainianEndings : englishEndings
        
        // Check if text ends with punctuation and has reasonable length
        let endsWithPunctuation = endings.contains { trimmedText.hasSuffix($0) }
        let hasMinimumLength = trimmedText.count > 10
        
        // Common complete phrases patterns
        let completePatterns = [
            // Ukrainian
            "дякую", "будь ласка", "до побачення", "привіт", "добре",
            // English  
            "thank you", "please", "goodbye", "hello", "okay", "yes", "no"
        ]
        
        let containsCompletePhrase = completePatterns.contains { pattern in
            trimmedText.lowercased().contains(pattern)
        }
        
        return (endsWithPunctuation && hasMinimumLength) || containsCompletePhrase
    }
    
    // MARK: - Silence Timer Management
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            self?.handleSilenceTimeout()
        }
    }
    
    private func handleSilenceTimeout() {
        guard isAutoListening else { return }
        
        // Check if we have meaningful speech
        if let lastSpeech = lastSpeechTime,
           Date().timeIntervalSince(lastSpeech) >= silenceThreshold {
            
            // Complete recognition with current text
            if let currentText = recognitionTask?.result?.bestTranscription.formattedString,
               !currentText.isEmpty && currentText != "🎤 Listening..." {
                completeSpeechRecognition(with: currentText)
            } else {
                stopListening()
            }
        }
    }
    
    private func completeSpeechRecognition(with text: String) {
        print("✅ Speech recognition completed: \(text)")
        stopListening()
        
        DispatchQueue.main.async {
            self.onSpeechComplete?(text)
        }
    }
    
    // MARK: - Control Methods
    func stopListening() {
        print("🛑 Stopping voice recognition...")
        isAutoListening = false
        silenceTimer?.invalidate()
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    // MARK: - ElevenLabs Text-to-Speech
    func speakWithElevenLabs(_ text: String, completion: @escaping (Bool) -> Void = { _ in }) {
        if AppConfiguration.Debug.enableVoiceLogging {
            print("🔊 Speaking with ElevenLabs: \(text.prefix(50))...")
        }
        
        guard isElevenLabsConfigured else {
            if AppConfiguration.Debug.enableVoiceLogging {
                print("⚠️ ElevenLabs API key not configured, falling back to system TTS")
            }
            speakWithSystemTTS(text)
            completion(true)
            return
        }
        
        generateSpeechWithElevenLabs(text: text)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        if AppConfiguration.Debug.enableVoiceLogging {
                            print("❌ ElevenLabs TTS failed: \(error), falling back to system TTS")
                        }
                        self.speakWithSystemTTS(text)
                        completion(false)
                    }
                },
                receiveValue: { audioData in
                    if AppConfiguration.Debug.enableVoiceLogging {
                        print("✅ ElevenLabs audio received: \(audioData.count) bytes")
                    }
                    self.playAudioData(audioData) { success in
                        completion(success)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func generateSpeechWithElevenLabs(text: String) -> AnyPublisher<Data, Error> {
        let url = URL(string: "\(elevenLabsBaseURL)/text-to-speech/\(selectedVoiceId)")!
        
        let voiceSettings = ElevenLabsVoiceRequest.VoiceSettings(
            stability: AppConfiguration.Voice.ElevenLabsSettings.stability,
            similarity_boost: AppConfiguration.Voice.ElevenLabsSettings.similarityBoost,
            style: AppConfiguration.Voice.ElevenLabsSettings.style,
            use_speaker_boost: AppConfiguration.Voice.ElevenLabsSettings.useSpeakerBoost
        )
        
        let request = ElevenLabsVoiceRequest(
            text: text,
            model_id: AppConfiguration.Voice.ElevenLabsSettings.modelId,
            voice_settings: voiceSettings
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .map(\.data)
            .eraseToAnyPublisher()
    }
    
    private func playAudioData(_ audioData: Data, completion: @escaping (Bool) -> Void) {
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            
            // Store completion handler
            audioPlayerCompletion = completion
            
            audioPlayer?.play()
        } catch {
            print("❌ Failed to play audio: \(error)")
            completion(false)
        }
    }
    
    // Store completion handler for audio player
    private var audioPlayerCompletion: ((Bool) -> Void)?
    
    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayerCompletion?(flag)
        audioPlayerCompletion = nil
    }
    
    // MARK: - Fallback System TTS
    private func speakWithSystemTTS(_ text: String) {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        
        // Enhanced voice settings
        let language = detectLanguage(from: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = language.starts(with: "uk") ? 
            AppConfiguration.Voice.SystemTTS.ukrainianRate : 
            AppConfiguration.Voice.SystemTTS.rate
        utterance.pitchMultiplier = AppConfiguration.Voice.SystemTTS.pitchMultiplier
        utterance.volume = AppConfiguration.Voice.SystemTTS.volume
        
        synthesizer.speak(utterance)
    }
    
    // MARK: - Language Detection
    private func detectLanguage(from text: String) -> String {
        let ukrainianChars = CharacterSet(charactersIn: "абвгґдеєжзиіїйклмнопрстуфхцчшщьюяыъэё")
        let textSet = CharacterSet(charactersIn: text.lowercased())
        
        if !ukrainianChars.intersection(textSet).isEmpty {
            return "uk-UA"
        }
        return "en-US"
    }
    
    // MARK: - Voice Management
    func getAvailableElevenLabsVoices() -> AnyPublisher<[ElevenLabsVoice], Error> {
        guard !elevenLabsAPIKey.isEmpty else {
            return Fail(error: NSError(domain: "VoiceService", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key not configured"]))
                .eraseToAnyPublisher()
        }
        
        let url = URL(string: "\(elevenLabsBaseURL)/voices")!
        var request = URLRequest(url: url)
        request.setValue(elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: VoicesResponse.self, decoder: JSONDecoder())
            .map(\.voices)
            .eraseToAnyPublisher()
    }
    
    private struct VoicesResponse: Codable {
        let voices: [ElevenLabsVoice]
    }
    
    // MARK: - SFSpeechRecognizerDelegate
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("🎤 Speech recognition availability: \(available)")
    }
} 