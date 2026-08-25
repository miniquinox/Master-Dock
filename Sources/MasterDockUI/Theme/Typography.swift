import SwiftUI

public enum AppTypography {
    public static let titleLarge = Font.system(size: 20, weight: .bold, design: .rounded)
    public static let titleMedium = Font.system(size: 16, weight: .semibold, design: .rounded)
    public static let titleSmall = Font.system(size: 14, weight: .semibold, design: .default)
    
    public static let body = Font.system(size: 13, weight: .regular, design: .default)
    public static let bodyBold = Font.system(size: 13, weight: .medium, design: .default)
    public static let caption = Font.system(size: 11, weight: .regular, design: .default)
    public static let captionBold = Font.system(size: 11, weight: .semibold, design: .default)
    public static let micro = Font.system(size: 9, weight: .medium, design: .default)
    
    public static let monoNumber = Font.system(size: 13, weight: .semibold, design: .monospaced)
    public static let monoClock = Font.system(size: 28, weight: .light, design: .rounded).monospacedDigit()
}
