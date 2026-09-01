import SwiftUI

public enum GlassTheme {
    // Apple Native macOS HUD Translucent Card Surfaces (Exact macOS Tone)
    public static let liquidGlassFill = LinearGradient(
        colors: [
            Color(red: 0.16, green: 0.17, blue: 0.19).opacity(0.78),
            Color(red: 0.10, green: 0.11, blue: 0.13).opacity(0.85)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let liquidGlassHoverFill = LinearGradient(
        colors: [
            Color(red: 0.20, green: 0.21, blue: 0.24).opacity(0.84),
            Color(red: 0.13, green: 0.14, blue: 0.17).opacity(0.90)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let pillGlassFill = LinearGradient(
        colors: [
            Color.white.opacity(0.13),
            Color.white.opacity(0.06)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Apple Sculpted Specular Glass Border Shine (Light striking from top-left)
    public static let liquidSpecularBorder = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.48), location: 0.0),   // Crisp bright top-left specular shine
            .init(color: Color.white.opacity(0.28), location: 0.25),  // Top rim illumination
            .init(color: Color.white.opacity(0.08), location: 0.65),  // Soft side rim
            .init(color: Color.white.opacity(0.18), location: 1.0)    // Gentle bottom-right reflection
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let subtleSpecularBorder = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.32), location: 0.0),
            .init(color: Color.white.opacity(0.18), location: 0.30),
            .init(color: Color.white.opacity(0.06), location: 0.70),
            .init(color: Color.white.opacity(0.14), location: 1.0)
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
                ZStack {
                    // Native macOS HUD Glass Material Blur (within card)
                    VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow, state: .active)
                    
                    // Native Apple HUD Smoky Translucent Tone
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isHovered ? GlassTheme.liquidGlassHoverFill : GlassTheme.liquidGlassFill)
                    
                    // Subtle Top Specular Glass Inner Light Sheen
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                // Apple Native Glass Border Rim Shine
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(GlassTheme.liquidSpecularBorder, lineWidth: 0.85)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.40), radius: isHovered ? 16 : 10, x: 0, y: isHovered ? 6 : 4)
            .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
    }
    
    func liquidPillStyle(cornerRadius: CGFloat = GlassTheme.pillRadius, isHovered: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isHovered ? GlassTheme.liquidGlassHoverFill : GlassTheme.pillGlassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(GlassTheme.subtleSpecularBorder, lineWidth: 0.75)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    func vibrantGlow(color: Color = GlassTheme.accentCyan, radius: CGFloat = 8) -> some View {
        self.shadow(color: color.opacity(0.55), radius: radius, x: 0, y: 0)
    }
}
