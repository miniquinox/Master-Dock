import SwiftUI

public struct AIPromptsSectionView: View {
    @ObservedObject public var promptService: PromptLibraryService
    public var onSelectPrompt: (PromptAction) -> Void
    
    public init(
        promptService: PromptLibraryService,
        onSelectPrompt: @escaping (PromptAction) -> Void
    ) {
        self.promptService = promptService
        self.onSelectPrompt = onSelectPrompt
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "AI Quick Actions",
                iconSystemName: "bolt.fill",
                count: promptService.favoritePrompts.count
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(promptService.favoritePrompts) { action in
                        Button(action: { onSelectPrompt(action) }) {
                            HStack(spacing: 6) {
                                Image(systemName: action.iconSystemName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(GlassTheme.accentCyan)
                                Text(action.title)
                                    .font(AppTypography.captionBold)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .liquidPillStyle(cornerRadius: 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.03),
                        .init(color: .black, location: 0.97),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }
}
