import Foundation
import AppKit
import Combine

public struct FolderItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let iconSystemName: String
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        url: URL,
        iconSystemName: String = "folder.fill"
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.iconSystemName = iconSystemName
    }
}

public final class FolderService: ObservableObject, FolderServiceProtocol {
    public static let shared = FolderService()
    
    @Published public private(set) var favoriteFolders: [FolderItem] = []
    private let storageKey = "favorite_folders"
    
    public init() {
        loadFolders()
    }
    
    public func openFolder(_ folder: FolderItem) {
        NSWorkspace.shared.open(folder.url)
    }
    
    public func addFolder(url: URL) {
        let name = url.lastPathComponent
        let item = FolderItem(
            id: url.path,
            name: name,
            url: url,
            iconSystemName: "folder.fill"
        )
        if !favoriteFolders.contains(where: { $0.url == url }) {
            favoriteFolders.append(item)
            persistFolders()
        }
    }
    
    public func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            addFolder(url: url)
        }
    }
    
    public func removeFolder(_ folder: FolderItem) {
        favoriteFolders.removeAll { $0.id == folder.id }
        persistFolders()
    }
    
    private func persistFolders() {
        PersistenceController.shared.save(favoriteFolders, forKey: storageKey)
    }
    
    private func loadFolders() {
        if let saved = PersistenceController.shared.load([FolderItem].self, forKey: storageKey), !saved.isEmpty {
            self.favoriteFolders = saved
        } else {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            
            self.favoriteFolders = [
                FolderItem(name: "Downloads", url: home.appendingPathComponent("Downloads"), iconSystemName: "arrow.down.circle.fill"),
                FolderItem(name: "Documents", url: home.appendingPathComponent("Documents"), iconSystemName: "doc.fill"),
                FolderItem(name: "Desktop", url: home.appendingPathComponent("Desktop"), iconSystemName: "macwindow"),
                FolderItem(name: "Developer", url: home.appendingPathComponent("Developer"), iconSystemName: "hammer.fill")
            ]
        }
    }
}
