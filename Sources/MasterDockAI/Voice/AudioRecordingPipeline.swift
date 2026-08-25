import Foundation
import AVFoundation
import Combine

public final class AudioRecordingPipeline: ObservableObject, @unchecked Sendable {
    public static let shared = AudioRecordingPipeline()
    
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordedFileURL: URL?
    
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var audioLevels: [Float] = Array(repeating: 0.1, count: 24)
    @Published public private(set) var averagePower: Float = 0.0
    
    public var onBufferCaptured: ((AVAudioPCMBuffer) -> Void)?
    
    private let queue = DispatchQueue(label: "com.masterdock.audiopipeline", qos: .userInitiated)
    
    public init() {}
    
    public func startRecording() -> (fileURL: URL?, inputFormat: AVAudioFormat?) {
        _ = stopRecording()
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("voice_input_\(UUID().uuidString).wav")
        self.recordedFileURL = fileURL
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            return (nil, nil)
        }
        
        do {
            let file = try AVAudioFile(forWriting: fileURL, settings: recordingFormat.settings)
            self.audioFile = file
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                
                // 1. Write audio to disk
                try? self.audioFile?.write(from: buffer)
                
                // 2. Stream to real-time speech recognizer
                SpeechTranscriptionService.shared.appendAudioBuffer(buffer)
                self.onBufferCaptured?(buffer)
                
                // 3. Compute RMS & Frequency bins for liquid waveform visualizer
                guard let channelData = buffer.floatChannelData?[0] else { return }
                let frameLength = UInt32(buffer.frameLength)
                var sum: Float = 0.0
                
                for i in 0..<Int(frameLength) {
                    let sample = channelData[i]
                    sum += sample * sample
                }
                
                let rms = sqrt(sum / Float(frameLength))
                let normalizedPower = max(0.05, min(1.0, rms * 12.0))
                
                DispatchQueue.main.async {
                    self.averagePower = normalizedPower
                    var newLevels = self.audioLevels
                    if !newLevels.isEmpty {
                        newLevels.removeFirst()
                        newLevels.append(normalizedPower)
                        self.audioLevels = newLevels
                    }
                }
            }
            
            try engine.start()
            self.audioEngine = engine
            
            DispatchQueue.main.async {
                self.isRecording = true
            }
            return (fileURL, recordingFormat)
        } catch {
            print("[AudioRecordingPipeline] Error starting audio engine: \(error)")
            return (nil, nil)
        }
    }
    
    public func stopRecording() -> URL? {
        guard isRecording, let engine = audioEngine else { return nil }
        
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioEngine = nil
        audioFile = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevels = Array(repeating: 0.05, count: 24)
            self.averagePower = 0.0
        }
        
        return recordedFileURL
    }
}
