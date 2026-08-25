import SwiftUI

public struct GlassButton: View {
    private let title: String
    private let iconSystemName: String?
    private let accentColor: Color?
    private let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    public init(
        title: String,
        iconSystemName: String? = nil,
        accentColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconSystemName = iconSystemName
        self.accentColor = accentColor
        self.action = action
    }
    
    private var buttonFillStyle: AnyShapeStyle {
        if let accent = accentColor {
            return AnyShapeStyle(accent.opacity(isHovered ? 0.90 : 0.75))
        } else if isHovered {
            return AnyShapeStyle(GlassTheme.liquidGlassHoverFill)
        } else {
            return AnyShapeStyle(GlassTheme.pillGlassFill)
        }
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = iconSystemName {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(AppTypography.bodyBold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                    .fill(buttonFillStyle)
                    .background(
                        RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                    .strokeBorder(GlassTheme.liquidSpecularBorder, lineWidth: 0.9)
            )
            .shadow(color: accentColor?.opacity(0.4) ?? GlassTheme.ambientShadow, radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 3 : 1)
            .scaleEffect(isPressed ? 0.96 : (isHovered ? 1.02 : 1.0))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                self.isHovered = hovering
            }
        }
    }
}

public struct GlassSearchBar: View {
    @Binding public var text: String
    public var placeholder: String
    @FocusState private var isFocused: Bool
    
    public init(text: Binding<String>, placeholder: String = "Search...") {
        self._text = text
        self.placeholder = placeholder
    }
    
    private var searchFillStyle: AnyShapeStyle {
        if isFocused {
            return AnyShapeStyle(GlassTheme.liquidGlassHoverFill)
        } else {
            return AnyShapeStyle(GlassTheme.pillGlassFill)
        }
    }
    
    private var searchBorderStyle: AnyShapeStyle {
        if isFocused {
            return AnyShapeStyle(GlassTheme.activeBorder)
        } else {
            return AnyShapeStyle(GlassTheme.subtleSpecularBorder)
        }
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
                .font(.system(size: 13, weight: .medium))
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AppTypography.body)
                .foregroundColor(.white)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                .fill(searchFillStyle)
                .background(
                    RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                .strokeBorder(searchBorderStyle, lineWidth: 0.8)
        )
    }
}

public struct SectionHeader: View {
    public let title: String
    public let iconSystemName: String
    public var count: Int?
    public var actionTitle: String?
    public var onAction: (() -> Void)?
    
    public init(
        title: String,
        iconSystemName: String,
        count: Int? = nil,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.iconSystemName = iconSystemName
        self.count = count
        self.actionTitle = actionTitle
        self.onAction = onAction
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconSystemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(GlassTheme.accentCyan)
            
            Text(title)
                .font(AppTypography.bodyBold)
                .foregroundColor(.white)
            
            if let count = count {
                Text("\(count)")
                    .font(AppTypography.micro)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                    )
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, let onAction = onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(AppTypography.captionBold)
                        .foregroundColor(GlassTheme.accentCyan)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
