import Foundation
import AppKit

public enum ClipboardContentType: String, Codable, Sendable {
    case text
    case image
    case url
    case code
    case color
    
    public static func classify(string: String) -> ClipboardContentType {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return .url
        }
        if (trimmed.hasPrefix("#") && (trimmed.count == 7 || trimmed.count == 9)) ||
           trimmed.hasPrefix("rgb(") || trimmed.hasPrefix("rgba(") {
            return .color
        }
        if trimmed.contains("func ") || trimmed.contains("class ") || trimmed.contains("import ") ||
           trimmed.contains("const ") || trimmed.contains("let ") || trimmed.contains("var ") ||
           trimmed.contains("def ") || trimmed.contains("return ") || trimmed.contains("{") {
            return .code
        }
        return .text
    }
}

public struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: ClipboardContentType
    public let textContent: String?
    public let imageData: Data?
    public let previewTitle: String
    public let previewSubtitle: String
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: ClipboardContentType,
        textContent: String? = nil,
        imageData: Data? = nil,
        previewTitle: String,
        previewSubtitle: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.textContent = textContent
        self.imageData = imageData
        self.previewTitle = previewTitle
        self.previewSubtitle = previewSubtitle
    }
}
