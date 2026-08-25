import SwiftUI

public struct GlassCard<Content: View>: View {
    private let content: Content
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    @State private var isHovered = false
    
    public init(
        cornerRadius: CGFloat = GlassTheme.cardRadius,
        padding: CGFloat = 14,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(padding)
            .liquidGlassCard(cornerRadius: cornerRadius, isHovered: isHovered)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.18)) {
                    self.isHovered = hovering
                }
            }
    }
}
