import SwiftUI
import AppKit

public struct MarkdownTextView: View {
    public let text: String
    public var textColor: Color
    
    public init(text: String, textColor: Color = .white.opacity(0.95)) {
        self.text = text
        self.textColor = textColor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseBlocks(from: text)) { block in
                renderBlock(block)
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level, let content):
            Text(inlineMarkdown(content))
                .font(headingFont(for: level))
                .foregroundColor(level == 3 ? GlassTheme.accentCyan : .white)
                .padding(.top, 2)
            
        case .codeBlock(let language, let code):
            MarkdownCodeBlockView(language: language, code: code)
            
        case .bulletItem(let content):
            HStack(alignment: .top, spacing: 6) {
                Circle()
                    .fill(GlassTheme.accentCyan)
                    .frame(width: 4, height: 4)
                    .padding(.top, 6)
                Text(inlineMarkdown(content))
                    .font(AppTypography.body)
                    .foregroundColor(textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
            
        case .numberedItem(let number, let content):
            HStack(alignment: .top, spacing: 6) {
                Text("\(number).")
                    .font(AppTypography.bodyBold)
                    .foregroundColor(GlassTheme.accentCyan)
                Text(inlineMarkdown(content))
                    .font(AppTypography.body)
                    .foregroundColor(textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
            
        case .blockquote(let content):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(GlassTheme.accentCyan.opacity(0.8))
                    .frame(width: 3)
                Text(inlineMarkdown(content))
                    .font(AppTypography.body.italic())
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            
        case .horizontalRule:
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
                .padding(.vertical, 4)
            
        case .paragraph(let content):
            Text(inlineMarkdown(content))
                .font(AppTypography.body)
                .foregroundColor(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: return .system(size: 15, weight: .bold)
        case 2: return .system(size: 14, weight: .semibold)
        default: return .system(size: 13, weight: .semibold)
        }
    }
    
    private func inlineMarkdown(_ string: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: string, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(string)
    }
    
    private func parseBlocks(from input: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let rawLines = input.components(separatedBy: .newlines)
        
        var inCodeBlock = false
        var currentCodeLanguage: String? = nil
        var currentCodeLines: [String] = []
        
        for rawLine in rawLines {
            let line = rawLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check Code Block boundaries (```)
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    blocks.append(MarkdownBlock(kind: .codeBlock(language: currentCodeLanguage, code: currentCodeLines.joined(separator: "\n"))))
                    currentCodeLines.removeAll()
                    currentCodeLanguage = nil
                    inCodeBlock = false
                } else {
                    // Start code block
                    inCodeBlock = true
                    let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    currentCodeLanguage = lang.isEmpty ? nil : lang
                }
                continue
            }
            
            if inCodeBlock {
                currentCodeLines.append(line)
                continue
            }
            
            if trimmed.isEmpty {
                continue
            }
            
            // Headings
            if trimmed.hasPrefix("### ") {
                blocks.append(MarkdownBlock(kind: .heading(level: 3, content: String(trimmed.dropFirst(4)))))
            } else if trimmed.hasPrefix("## ") {
                blocks.append(MarkdownBlock(kind: .heading(level: 2, content: String(trimmed.dropFirst(3)))))
            } else if trimmed.hasPrefix("# ") {
                blocks.append(MarkdownBlock(kind: .heading(level: 1, content: String(trimmed.dropFirst(2)))))
            } else if trimmed.hasPrefix("> ") {
                blocks.append(MarkdownBlock(kind: .blockquote(content: String(trimmed.dropFirst(2)))))
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(MarkdownBlock(kind: .horizontalRule))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                blocks.append(MarkdownBlock(kind: .bulletItem(content: String(trimmed.dropFirst(2)))))
            } else if let numMatch = parseNumberedItem(trimmed) {
                blocks.append(MarkdownBlock(kind: .numberedItem(number: numMatch.number, content: numMatch.content)))
            } else {
                blocks.append(MarkdownBlock(kind: .paragraph(content: line)))
            }
        }
        
        // If code block was not closed
        if inCodeBlock && !currentCodeLines.isEmpty {
            blocks.append(MarkdownBlock(kind: .codeBlock(language: currentCodeLanguage, code: currentCodeLines.joined(separator: "\n"))))
        }
        
        return blocks
    }
    
    private func parseNumberedItem(_ line: String) -> (number: Int, content: String)? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let prefix = line[..<dotIndex]
        if let num = Int(prefix), line.index(after: dotIndex) < line.endIndex {
            let afterDot = line[line.index(after: dotIndex)...].trimmingCharacters(in: .whitespaces)
            return (number: num, content: afterDot)
        }
        return nil
    }
}

public struct MarkdownBlock: Identifiable {
    public let id = UUID()
    public let kind: Kind
    
    public enum Kind {
        case heading(level: Int, content: String)
        case codeBlock(language: String?, code: String)
        case bulletItem(content: String)
        case numberedItem(number: Int, content: String)
        case blockquote(content: String)
        case horizontalRule
        case paragraph(content: String)
    }
}

public struct MarkdownCodeBlockView: View {
    public let language: String?
    public let code: String
    @State private var isCopied = false
    
    public init(language: String?, code: String) {
        self.language = language
        self.code = code
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language?.uppercased() ?? "CODE")
                    .font(AppTypography.micro)
                    .foregroundColor(.white.opacity(0.65))
                
                Spacer()
                
                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(AppTypography.micro)
                    }
                    .foregroundColor(isCopied ? GlassTheme.accentEmerald : .white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.40))
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0.90, green: 0.96, blue: 1.0))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.black.opacity(0.30))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
        )
    }
    
    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}
