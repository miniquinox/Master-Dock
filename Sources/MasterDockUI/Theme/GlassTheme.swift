import SwiftUI

public enum GlassTheme {
    // Apple Native Translucent Card Surfaces (Matching macOS Notification Center)
    public static let liquidGlassFill = LinearGradient(
        colors: [
            Color(white: 0.22).opacity(0.60),
            Color(white: 0.14).opacity(0.65)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let liquidGlassHoverFill = LinearGradient(
        colors: [
            Color(white: 0.28).opacity(0.70),
            Color(white: 0.18).opacity(0.75)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let pillGlassFill = LinearGradient(
        colors: [
            Color.white.opacity(0.15),
            Color.white.opacity(0.06)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Apple Delicate Specular Rim Bevels
    public static let liquidSpecularBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.35),
            Color.white.opacity(0.12),
            Color.white.opacity(0.04),
            Color.white.opacity(0.20)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let subtleSpecularBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.20),
            Color.white.opacity(0.06),
            Color.white.opacity(0.02),
            Color.white.opacity(0.10)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let activeBorder = LinearGradient(
        colors: [
            Color(red: 0.40, green: 0.75, blue: 1.0),
            Color(red: 0.70, green: 0.45, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Vibrant Accents
    public static let accentBlue = Color(red: 0.0, green: 0.50, blue: 1.0)
    public static let accentPurple = Color(red: 0.70, green: 0.35, blue: 0.90)
    public static let accentEmerald = Color(red: 0.20, green: 0.82, blue: 0.40)
    public static let accentAmber = Color(red: 1.0, green: 0.60, blue: 0.0)
    public static let accentRose = Color(red: 1.0, green: 0.22, blue: 0.38)
    public static let accentCyan = Color(red: 0.25, green: 0.85, blue: 1.0)
    
    // Radii
    public static let cardRadius: CGFloat = 20
    public static let dockRadius: CGFloat = 24
    public static let pillRadius: CGFloat = 12
    
    // Ambient Depth Shadows
    public static let ambientShadow = Color.black.opacity(0.35)
    public static let specularGlow = Color.white.opacity(0.12)
}

public extension View {
    func liquidGlassCard(cornerRadius: CGFloat = GlassTheme.cardRadius, isHovered: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHovered ? GlassTheme.liquidGlassHoverFill : GlassTheme.liquidGlassFill)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(GlassTheme.liquidSpecularBorder, lineWidth: 0.65)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: GlassTheme.ambientShadow, radius: isHovered ? 12 : 7, x: 0, y: isHovered ? 6 : 3)
    }
    
    func liquidPillStyle(cornerRadius: CGFloat = GlassTheme.pillRadius, isHovered: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHovered ? GlassTheme.liquidGlassHoverFill : GlassTheme.pillGlassFill)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(GlassTheme.subtleSpecularBorder, lineWidth: 0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    func vibrantGlow(color: Color = GlassTheme.accentCyan, radius: CGFloat = 8) -> some View {
        self.shadow(color: color.opacity(0.55), radius: radius, x: 0, y: 0)
    }
}
