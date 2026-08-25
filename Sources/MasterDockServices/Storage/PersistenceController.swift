import Foundation

public final class PersistenceController: @unchecked Sendable {
    public static let shared = PersistenceController()
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.masterdock.persistence", qos: .utility)
    
    private var storageDirectory: URL {
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = appSupport.appendingPathComponent("MasterDock", isDirectory: true)
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
            }
            if fileManager.fileExists(atPath: dir.path) {
                return dir
            }
        }
        // Fallback to Documents or Temporary Directory
        let fallback = fileManager.temporaryDirectory.appendingPathComponent("MasterDock", isDirectory: true)
        if !fileManager.fileExists(atPath: fallback.path) {
            try? fileManager.createDirectory(at: fallback, withIntermediateDirectories: true, attributes: nil)
        }
        return fallback
    }
    
    public func save<T: Encodable>(_ object: T, forKey key: String) {
        queue.async {
            do {
                let data = try JSONEncoder().encode(object)
                let dir = self.storageDirectory
                let fileURL = dir.appendingPathComponent("\(key).json")
                try data.write(to: fileURL, options: .atomic)
                UserDefaults.standard.set(data, forKey: "md_\(key)")
            } catch {
                if let data = try? JSONEncoder().encode(object) {
                    UserDefaults.standard.set(data, forKey: "md_\(key)")
                }
            }
        }
    }
    
    public func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        let fileURL = storageDirectory.appendingPathComponent("\(key).json")
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(type, from: data) {
            return decoded
        }
        
        // Fallback to UserDefaults
        if let data = UserDefaults.standard.data(forKey: "md_\(key)"),
           let decoded = try? JSONDecoder().decode(type, from: data) {
            return decoded
        }
        
        return nil
    }
}
