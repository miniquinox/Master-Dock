import Foundation
import AppKit
import Combine

public struct WallpaperItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let category: String
    public let fileURL: URL?
    public let primaryColorHex: String
    public let secondaryColorHex: String
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        category: String,
        fileURL: URL? = nil,
        primaryColorHex: String = "#3A88E9",
        secondaryColorHex: String = "#9055FF"
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.fileURL = fileURL
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHex = secondaryColorHex
    }
}

public final class WallpaperService: ObservableObject, WallpaperServiceProtocol {
    public static let shared = WallpaperService()
    
    @Published public private(set) var wallpapers: [WallpaperItem] = []
    @Published public private(set) var currentWallpaperName: String = "Default"
    
    public init() {
        loadWallpapers()
    }
    
    public func loadWallpapers() {
        var items: [WallpaperItem] = []
        let fileManager = FileManager.default
        
        // 1. Primary macOS Desktop Pictures Directory
        let systemDir = URL(fileURLWithPath: "/System/Library/Desktop Pictures")
        if let files = try? fileManager.contentsOfDirectory(at: systemDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "heic" || file.pathExtension == "jpg" || file.pathExtension == "png" {
                let name = file.deletingPathExtension().lastPathComponent
                items.append(WallpaperItem(
                    id: file.path,
                    name: name,
                    category: "macOS Default",
                    fileURL: file,
                    primaryColorHex: "#2563EB",
                    secondaryColorHex: "#7C3AED"
                ))
            }
        }
        
        // 2. Curated macOS Dynamic & Heritage Wallpapers (.thumbnails)
        let thumbnailsDir = systemDir.appendingPathComponent(".thumbnails")
        let curatedNames = [
            "Big Sur", "Catalina", "Ventura Graphic", "Monterey Graphic",
            "The Desert", "The Beach", "The Lake", "Valley", "Peak",
            "Solar Gradients", "Iridescence", "Chroma Blue", "Light Stream Blue"
        ]
        for name in curatedNames {
            let fileURL = thumbnailsDir.appendingPathComponent("\(name).heic")
            if fileManager.fileExists(atPath: fileURL.path) {
                items.append(WallpaperItem(
                    id: fileURL.path,
                    name: name,
                    category: "macOS Classic",
                    fileURL: fileURL,
                    primaryColorHex: "#3B82F6",
                    secondaryColorHex: "#10B981"
                ))
            }
        }
        
        // 3. Apple Solid Color Wallpapers
        let solidColorsDir = systemDir.appendingPathComponent("Solid Colors")
        let solidNames = ["Space Gray Pro", "Electric Blue", "Teal", "Cyan", "Blue Violet", "Black", "Plum"]
        for name in solidNames {
            let fileURL = solidColorsDir.appendingPathComponent("\(name).png")
            if fileManager.fileExists(atPath: fileURL.path) {
                items.append(WallpaperItem(
                    id: fileURL.path,
                    name: name,
                    category: "Solid Colors",
                    fileURL: fileURL,
                    primaryColorHex: "#1E293B",
                    secondaryColorHex: "#0F172A"
                ))
            }
        }
        
        // Detect current desktop wallpaper name if available
        if let screen = NSScreen.main, let currentURL = NSWorkspace.shared.desktopImageURL(for: screen) {
            self.currentWallpaperName = currentURL.deletingPathExtension().lastPathComponent
        }
        
        self.wallpapers = items
    }
    
    public func setWallpaper(_ item: WallpaperItem) {
        self.currentWallpaperName = item.name
        guard let url = item.fileURL else { return }
        
        // 1. Native AppKit NSWorkspace API
        for screen in NSScreen.screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            } catch {
                print("[WallpaperService] NSWorkspace error setting wallpaper: \(error)")
            }
        }
        
        // 2. AppleScript Fallback to ensure all Mission Control spaces and active desktops refresh
        let scriptSource = """
        tell application "System Events"
            tell current desktop
                set picture to POSIX file "\(url.path)"
            end tell
            try
                tell every desktop
                    set picture to POSIX file "\(url.path)"
                end tell
            end try
        end tell
        """
        if let appleScript = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
        }
    }
    
    public func chooseCustomWallpaper() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.title = "Choose Desktop Wallpaper"
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            let customItem = WallpaperItem(
                id: url.path,
                name: url.deletingPathExtension().lastPathComponent,
                category: "Custom",
                fileURL: url,
                primaryColorHex: "#06B6D4",
                secondaryColorHex: "#3B82F6"
            )
            wallpapers.insert(customItem, at: 0)
            setWallpaper(customItem)
        }
    }
}
