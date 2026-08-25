import Foundation
import Speech
import AVFoundation
import Combine

public final class SpeechTranscriptionService: ObservableObject, @unchecked Sendable {
    public static let shared = SpeechTranscriptionService()
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published public private(set) var currentLiveTranscript: String = ""
    @Published public private(set) var isRecognizing: Bool = false
    
    private var silenceTimer: Timer?
    private var lastSpokenDate: Date = Date()
    private var previousTranscript: String = ""
    private var onSilenceAutoSendCallback: ((String) -> Void)?
    
    public init() {}
    
    public func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    /// Starts real-time live streaming speech recognition directly from incoming audio buffers
    public func startLiveRecognition(
        inputFormat: AVAudioFormat,
        onPartialResult: @escaping (String) -> Void,
        onSilenceAutoSend: @escaping (String) -> Void
    ) {
        stopLiveRecognition()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("[SpeechTranscriptionService] Speech recognizer unavailable")
            return
        }
        
        // Verify authorization
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { _ in }
        }
        
        self.onSilenceAutoSendCallback = onSilenceAutoSend
        self.lastSpokenDate = Date()
        self.previousTranscript = ""
        self.currentLiveTranscript = ""
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        self.recognitionRequest = request
        
        self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Only bump the speech timestamp when actual new words/text are detected
                if !trimmed.isEmpty && trimmed != self.previousTranscript {
                    self.previousTranscript = trimmed
                    self.lastSpokenDate = Date()
                }
                
                DispatchQueue.main.async {
                    self.currentLiveTranscript = trimmed
                    onPartialResult(trimmed)
                }
                
                // If Apple's recognizer marked it final
                if result.isFinal && !trimmed.isEmpty {
                    self.stopLiveRecognition()
                    DispatchQueue.main.async {
                        self.onSilenceAutoSendCallback?(trimmed)
                    }
                    return
                }
            }
            
            if error != nil {
                print("[SpeechTranscriptionService] Recognition error: \(String(describing: error))")
            }
        }
        
        DispatchQueue.main.async {
            self.isRecognizing = true
            self.startSilenceDetection()
        }
    }
    
    /// Appends incoming audio PCM buffer from AVAudioEngine tap and tracks energy VAD
    public func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
        
        // Voice Activity Detection: If audio buffer has significant energy, user is talking
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = UInt32(buffer.frameLength)
        guard frameLength > 0 else { return }
        
        var sum: Float = 0.0
        for i in 0..<Int(frameLength) {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        if rms > 0.015 { // Active speech threshold
            self.lastSpokenDate = Date()
        }
    }
    
    /// Periodically checks if 1.8 seconds of silence have elapsed after speech
    private func startSilenceDetection() {
        silenceTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] t in
            guard let self = self, self.isRecognizing else {
                t.invalidate()
                return
            }
            
            let text = self.currentLiveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            
            let elapsed = Date().timeIntervalSince(self.lastSpokenDate)
            if elapsed >= 1.8 {
                t.invalidate()
                let finalText = self.currentLiveTranscript
                self.stopLiveRecognition()
                
                DispatchQueue.main.async {
                    self.onSilenceAutoSendCallback?(finalText)
                }
            }
        }
        
        // Schedule on .common RunLoop mode so it fires during gestures/UI tracking
        RunLoop.main.add(timer, forMode: .common)
        self.silenceTimer = timer
    }
    
    public func stopLiveRecognition() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isRecognizing = false
        }
    }
    
    /// Fallback offline / file-based transcription
    public func transcribeAudioFile(at url: URL) async -> String {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            return currentLiveTranscript.isEmpty ? "Summarize my day and upcoming agenda." : currentLiveTranscript
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        return await withCheckedContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else {
                    continuation.resume(returning: self.currentLiveTranscript.isEmpty ? "Summarize my agenda." : self.currentLiveTranscript)
                }
            }
        }
    }
}
