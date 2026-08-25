import Foundation
import AppKit
import Combine

public enum MediaSource: String, Codable, Sendable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "YouTube Music"
    case none = "None"
}

public struct MediaTrack: Equatable, Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let artworkData: Data?
    public let isPlaying: Bool
    public let source: MediaSource
    
    public init(
        title: String,
        artist: String,
        album: String = "",
        artworkData: Data? = nil,
        isPlaying: Bool,
        source: MediaSource
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkData = artworkData
        self.isPlaying = isPlaying
        self.source = source
    }
}

public final class MediaService: ObservableObject, MediaServiceProtocol {
    public static let shared = MediaService()
    
    @Published public private(set) var currentTrack: MediaTrack?
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var activeSource: MediaSource = .none
    
    private var pollTimer: Timer?
    
    public init() {
        startPolling()
    }
    
    public func startPolling() {
        refreshState()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
    }
    
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    public func refreshState() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Check Spotify first
            if let track = self?.querySpotify() {
                DispatchQueue.main.async {
                    self?.currentTrack = track
                    self?.isPlaying = track.isPlaying
                    self?.activeSource = .spotify
                }
                return
            }
            
            // Check Apple Music
            if let track = self?.queryAppleMusic() {
                DispatchQueue.main.async {
                    self?.currentTrack = track
                    self?.isPlaying = track.isPlaying
                    self?.activeSource = .appleMusic
                }
                return
            }
            
            // Default placeholder if none running
            DispatchQueue.main.async {
                self?.currentTrack = MediaTrack(
                    title: "Ready to Play",
                    artist: "Apple Music, Spotify & YouTube",
                    album: "Master Dock Controller",
                    artworkData: nil,
                    isPlaying: false,
                    source: .none
                )
                self?.isPlaying = false
                self?.activeSource = .none
            }
        }
    }
    
    private func querySpotify() -> MediaTrack? {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                if player state is playing or player state is paused then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set playState to (player state is playing)
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & playState
                end if
            end tell
        end if
        return "NONE"
        """
        
        guard let output = runAppleScript(script), output != "NONE" else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 4 else { return nil }
        
        return MediaTrack(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            artworkData: nil,
            isPlaying: parts[3].trimmingCharacters(in: .whitespacesAndNewlines) == "true",
            source: .spotify
        )
    }
    
    private func queryAppleMusic() -> MediaTrack? {
        let script = """
        if application "Music" is running then
            tell application "Music"
                if player state is playing or player state is paused then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set playState to (player state is playing)
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & playState
                end if
            end tell
        end if
        return "NONE"
        """
        
        guard let output = runAppleScript(script), output != "NONE" else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 4 else { return nil }
        
        return MediaTrack(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            artworkData: nil,
            isPlaying: parts[3].trimmingCharacters(in: .whitespacesAndNewlines) == "true",
            source: .appleMusic
        )
    }
    
    public func playPause() {
        switch activeSource {
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to playpause")
        case .appleMusic:
            _ = runAppleScript("tell application \"Music\" to playpause")
        default:
            // Media key toggle fallback
            sendSystemMediaKey(key: 16) // NX_KEYTYPE_PLAY
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshState()
        }
    }
    
    public func nextTrack() {
        switch activeSource {
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to next track")
        case .appleMusic:
            _ = runAppleScript("tell application \"Music\" to next track")
        default:
            sendSystemMediaKey(key: 17) // NX_KEYTYPE_NEXT
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshState()
        }
    }
    
    public func previousTrack() {
        switch activeSource {
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to previous track")
        case .appleMusic:
            _ = runAppleScript("tell application \"Music\" to previous track")
        default:
            sendSystemMediaKey(key: 18) // NX_KEYTYPE_PREVIOUS
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshState()
        }
    }
    
    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return output.stringValue
            }
        }
        return nil
    }
    
    private func sendSystemMediaKey(key: Int32) {
        func postKey(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            if let cgev = ev?.cgEvent {
                cgev.post(tap: .cghidEventTap)
            }
        }
        postKey(down: true)
        postKey(down: false)
    }
}
