import SwiftUI

public struct MasterDockRootView: View {
    @ObservedObject public var clipboardService: ClipboardMonitorService
    @ObservedObject public var mediaService: MediaService
    @ObservedObject public var calendarService: CalendarService
    @ObservedObject public var wallpaperService: WallpaperService
    @ObservedObject public var appLauncher: AppLauncherService
    @ObservedObject public var folderService: FolderService
    @ObservedObject public var statsService: SystemStatsService
    @ObservedObject public var weatherService: WeatherService
    @ObservedObject public var checklistService: ChecklistService
    @ObservedObject public var promptService: PromptLibraryService
    @ObservedObject public var audioPipeline: AudioRecordingPipeline
    
    @Binding public var isVoiceModeActive: Bool
    @Binding public var liveVoiceTranscript: String
    @Binding public var aiPromptInput: String
    @Binding public var conversationHistory: [AIMessage]
    @Binding public var isAIStreaming: Bool
    
    public var onSendMessage: (String) -> Void
    public var onClearChat: () -> Void
    public var onVoiceDone: () -> Void
    public var onStartVoice: () -> Void
    public var onOpenSettings: () -> Void
    public var onDismiss: () -> Void
    
    @State private var selectedTab: DockTab = .all
    
    public enum DockTab: String, CaseIterable, Identifiable {
        case all = "All"
        case ai = "AI"
        case clipboard = "Clipboard"
        case agenda = "Agenda"
        case apps = "Apps"
        case widgets = "Widgets"
        
        public var id: String { rawValue }
    }
    
    public init(
        clipboardService: ClipboardMonitorService = .shared,
        mediaService: MediaService = .shared,
        calendarService: CalendarService = .shared,
        wallpaperService: WallpaperService = .shared,
        appLauncher: AppLauncherService = .shared,
        folderService: FolderService = .shared,
        statsService: SystemStatsService = .shared,
        weatherService: WeatherService = .shared,
        checklistService: ChecklistService = .shared,
        promptService: PromptLibraryService = .shared,
        audioPipeline: AudioRecordingPipeline = .shared,
        isVoiceModeActive: Binding<Bool>,
        liveVoiceTranscript: Binding<String> = .constant(""),
        aiPromptInput: Binding<String>,
        conversationHistory: Binding<[AIMessage]>,
        isAIStreaming: Binding<Bool>,
        onSendMessage: @escaping (String) -> Void,
        onClearChat: @escaping () -> Void,
        onVoiceDone: @escaping () -> Void,
        onStartVoice: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.clipboardService = clipboardService
        self.mediaService = mediaService
        self.calendarService = calendarService
        self.wallpaperService = wallpaperService
        self.appLauncher = appLauncher
        self.folderService = folderService
        self.statsService = statsService
        self.weatherService = weatherService
        self.checklistService = checklistService
        self.promptService = promptService
        self.audioPipeline = audioPipeline
        self._isVoiceModeActive = isVoiceModeActive
        self._liveVoiceTranscript = liveVoiceTranscript
        self._aiPromptInput = aiPromptInput
        self._conversationHistory = conversationHistory
        self._isAIStreaming = isAIStreaming
        self.onSendMessage = onSendMessage
        self.onClearChat = onClearChat
        self.onVoiceDone = onVoiceDone
        self.onStartVoice = onStartVoice
        self.onOpenSettings = onOpenSettings
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            if isVoiceModeActive {
                AIVoiceOverlayView(
                    audioPipeline: audioPipeline,
                    liveTranscript: liveVoiceTranscript,
                    userPrompt: conversationHistory.filter { $0.role == .user }.last?.content ?? "",
                    aiResponseText: conversationHistory.filter { $0.role == .assistant }.last?.content ?? "",
                    isAIStreaming: isAIStreaming,
                    onClose: { isVoiceModeActive = false },
                    onStopAndSend: onVoiceDone,
                    onStartRecording: onStartVoice
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                standardDockContent
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isVoiceModeActive)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private var standardDockContent: some View {
        VStack(spacing: 10) {
            // Floating Top Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "dock.rectangle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(GlassTheme.accentCyan)
                    
                    Text("Master Dock")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { isVoiceModeActive = true; onStartVoice() }) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(7)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    .help("Open Apple Intelligence Voice Companion")
                    
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(7)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(7)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .liquidGlassCard(cornerRadius: 18)
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.top, 38)
            
            // Floating Tab Filter Bar (Smooth Single-Line Scrollable)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DockTab.allCases) { tab in
                        Button(action: { selectedTab = tab }) {
                            Text(tab.rawValue)
                                .font(AppTypography.captionBold)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.75))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    ZStack {
                                        if selectedTab == tab {
                                            Capsule()
                                                .fill(GlassTheme.accentBlue.opacity(0.90))
                                        } else {
                                            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                                            Capsule()
                                                .fill(GlassTheme.pillGlassFill)
                                        }
                                    }
                                    .clipShape(Capsule())
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(selectedTab == tab ? AnyShapeStyle(Color.white.opacity(0.5)) : AnyShapeStyle(GlassTheme.subtleSpecularBorder), lineWidth: 0.65)
                                )
                                .shadow(color: Color.black.opacity(0.20), radius: 3, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.bottom, 2)
            
            // Main Scrollable Floating Cards
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    // 1. Apple Intelligence & Prompts
                    if selectedTab == .all || selectedTab == .ai {
                        GlassCard {
                            VStack(spacing: 12) {
                                AIChatSectionView(
                                    promptText: $aiPromptInput,
                                    conversation: $conversationHistory,
                                    isStreaming: $isAIStreaming,
                                    onSendMessage: onSendMessage,
                                    onClear: onClearChat
                                )
                                
                                AIPromptsSectionView(promptService: promptService) { action in
                                    let clipboardText = clipboardService.items.first(where: { $0.type == .text })?.textContent ?? ""
                                    let resolved = promptService.resolvePrompt(action, clipboardContent: clipboardText)
                                    onSendMessage(resolved)
                                }
                            }
                        }
                    }
                    
                    // 2. Clipboard History
                    if selectedTab == .all || selectedTab == .clipboard {
                        GlassCard {
                            ClipboardSectionView(clipboardService: clipboardService)
                        }
                    }
                    
                    // 3. Today's Calendar & Schedule
                    if selectedTab == .all || selectedTab == .agenda {
                        GlassCard {
                            CalendarSectionView(calendarService: calendarService)
                        }
                    }
                    
                    // 4. Media Controller
                    if selectedTab == .all || selectedTab == .agenda {
                        GlassCard {
                            MediaSectionView(mediaService: mediaService)
                        }
                    }
                    
                    // 5. Daily Checklist
                    if selectedTab == .all || selectedTab == .agenda {
                        GlassCard {
                            ChecklistSectionView(checklistService: checklistService)
                        }
                    }
                    
                    // 6. Favorite Apps & Quick Folders
                    if selectedTab == .all || selectedTab == .apps {
                        GlassCard {
                            AppFolderSectionView(appLauncher: appLauncher, folderService: folderService)
                        }
                    }
                    
                    // 7. Wallpapers
                    if selectedTab == .all || selectedTab == .widgets {
                        GlassCard {
                            WallpaperSectionView(wallpaperService: wallpaperService)
                        }
                    }
                    
                    // 8. Widget Drawer & System Stats
                    if selectedTab == .all || selectedTab == .widgets {
                        GlassCard {
                            WidgetDrawerSectionView(statsService: statsService, weatherService: weatherService)
                        }
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 10)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
    }
}
