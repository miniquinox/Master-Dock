import Foundation
import AppKit

public final class ClipboardMonitorService: ObservableObject, @unchecked Sendable {
    public static let shared = ClipboardMonitorService()
    
    @Published public private(set) var items: [ClipboardItem] = []
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let maxHistoryLimit: Int = 50
    private let persistence = PersistenceController.shared
    
    public init() {
        loadPersistedHistory()
        startMonitoring()
    }
    
    public func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkForNewClipboardContent()
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForNewClipboardContent() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        // 1. Check for image content
        if let imageTypes = pasteboard.types, imageTypes.contains(.png) || imageTypes.contains(.tiff) {
            if let imgData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
                let img = NSImage(data: imgData)
                let sizeStr = img != nil ? "\(Int(img!.size.width)) × \(Int(img!.size.height))" : "Image"
                let byteCountStr = ByteCountFormatter.string(fromByteCount: Int64(imgData.count), countStyle: .file)
                
                let item = ClipboardItem(
                    type: .image,
                    imageData: imgData,
                    previewTitle: "Image (\(sizeStr))",
                    previewSubtitle: "\(byteCountStr) • \(timeFormatted(Date()))"
                )
                appendItem(item)
                return
            }
        }
        
        // 2. Check for string content
        if let string = pasteboard.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let type = ClipboardContentType.classify(string: string)
            let previewTitle = string.prefix(60).replacingOccurrences(of: "\n", with: " ")
            let charCount = string.count
            let previewSubtitle = "\(charCount) chars • \(timeFormatted(Date()))"
            
            let item = ClipboardItem(
                type: type,
                textContent: string,
                previewTitle: String(previewTitle),
                previewSubtitle: previewSubtitle
            )
            appendItem(item)
        }
    }
    
    private func appendItem(_ item: ClipboardItem) {
        // Avoid duplicate sequential items
        if let first = items.first {
            if first.textContent == item.textContent && first.imageData == item.imageData {
                return
            }
        }
        
        DispatchQueue.main.async {
            self.items.insert(item, at: 0)
            if self.items.count > self.maxHistoryLimit {
                self.items = Array(self.items.prefix(self.maxHistoryLimit))
            }
            self.persistHistory()
        }
    }
    
    public func copyItemToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if let text = item.textContent {
            pasteboard.setString(text, forType: .string)
            if item.type == .url, let url = URL(string: text) {
                pasteboard.setData(url.dataRepresentation, forType: .URL)
            }
        } else if let data = item.imageData {
            pasteboard.setData(data, forType: .png)
            pasteboard.setData(data, forType: .tiff)
        }
        lastChangeCount = pasteboard.changeCount
    }
    
    public func pasteItemDirectly(_ item: ClipboardItem) {
        copyItemToPasteboard(item)
        
        // Synthesize Command + V keystroke to paste into previously active app
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15) {
            let src = CGEventSource(stateID: .hidSystemState)
            let vKeyCode: CGKeyCode = 9 // 'v' key
            
            if let keyDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true),
               let keyUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false) {
                keyDown.flags = .maskCommand
                keyUp.flags = .maskCommand
                keyDown.post(tap: .cghidEventTap)
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }
    
    public func clearHistory() {
        DispatchQueue.main.async {
            self.items.removeAll()
            self.persistHistory()
        }
    }
    
    private func persistHistory() {
        persistence.save(items, forKey: "clipboard_history")
    }
    
    private func loadPersistedHistory() {
        if let loaded = persistence.load([ClipboardItem].self, forKey: "clipboard_history") {
            self.items = loaded
        }
    }
    
    private func timeFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
