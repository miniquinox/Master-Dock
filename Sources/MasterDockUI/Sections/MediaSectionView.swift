import SwiftUI

public struct MediaSectionView: View {
    @ObservedObject public var mediaService: MediaService
    
    public init(mediaService: MediaService) {
        self.mediaService = mediaService
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "Media Controller",
                iconSystemName: "music.note"
            )
            
            HStack(spacing: 12) {
                // Album Art / Music Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [GlassTheme.accentRose, GlassTheme.accentPurple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                        )
                    
                    Image(systemName: mediaService.isPlaying ? "waveform" : "music.note")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Track Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(mediaService.currentTrack?.title ?? "No Active Playback")
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(mediaService.currentTrack?.artist ?? "Apple Music, Spotify & YouTube")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Transport Controls
                HStack(spacing: 6) {
                    Button(action: { mediaService.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { mediaService.playPause() }) {
                        Image(systemName: mediaService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(GlassTheme.accentBlue))
                            .vibrantGlow(color: GlassTheme.accentBlue, radius: 4)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { mediaService.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .liquidPillStyle(cornerRadius: 14)
        }
    }
}

public struct ChecklistSectionView: View {
    @ObservedObject public var checklistService: ChecklistService
    @State private var newTaskTitle = ""
    
    public init(checklistService: ChecklistService) {
        self.checklistService = checklistService
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with Progress Badge
            HStack {
                SectionHeader(
                    title: "Daily Checklist",
                    iconSystemName: "checklist",
                    count: checklistService.items.count,
                    actionTitle: checklistService.completedCount > 0 ? "Clear Done" : nil,
                    onAction: { checklistService.clearCompleted() }
                )
                
                Spacer()
                
                // Liquid Progress Badge
                if !checklistService.items.isEmpty {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 2.5)
                                .frame(width: 14, height: 14)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(checklistService.progressPercentage))
                                .stroke(GlassTheme.accentEmerald, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .frame(width: 14, height: 14)
                                .rotationEffect(.degrees(-90))
                        }
                        
                        Text("\(checklistService.completedCount)/\(checklistService.items.count)")
                            .font(AppTypography.micro)
                            .foregroundColor(checklistService.progressPercentage >= 1.0 ? GlassTheme.accentEmerald : .white.opacity(0.75))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .liquidPillStyle(cornerRadius: 10)
                }
            }
            
            // Task List (Full Row Click to Toggle)
            if checklistService.items.isEmpty {
                HStack {
                    Spacer()
                    Text("No tasks yet. Add one below to stay productive!")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 6)
                    Spacer()
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(checklistService.items) { item in
                        ChecklistItemRow(item: item) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                checklistService.toggleItem(item)
                            }
                        } onDelete: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                checklistService.removeItem(item)
                            }
                        }
                    }
                }
            }
            
            // New Task Input Box (Liquid Glass Pill)
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(GlassTheme.accentCyan)
                    .font(.system(size: 14))
                
                TextField("Add task for today...", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(AppTypography.body)
                    .foregroundColor(.white)
                    .onSubmit {
                        submitNewTask()
                    }
                
                if !newTaskTitle.isEmpty {
                    Button(action: submitNewTask) {
                        Text("Add")
                            .font(AppTypography.captionBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(GlassTheme.accentBlue))
                            .shadow(color: GlassTheme.accentBlue.opacity(0.4), radius: 4, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidPillStyle(cornerRadius: 12)
        }
    }
    
    private func submitNewTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        checklistService.addItem(title: title)
        newTaskTitle = ""
    }
}

private struct ChecklistItemRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                // Checkbox Icon
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(item.isCompleted ? GlassTheme.accentEmerald : .white.opacity(0.45))
                    .scaleEffect(item.isCompleted ? 1.08 : 1.0)
                
                // Task Title
                Text(item.title)
                    .font(AppTypography.body)
                    .foregroundColor(item.isCompleted ? .white.opacity(0.40) : .white.opacity(0.95))
                    .strikethrough(item.isCompleted, color: GlassTheme.accentEmerald.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Delete Action on Hover
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(4)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Delete task")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.isCompleted ? AnyShapeStyle(GlassTheme.accentEmerald.opacity(0.18)) : (isHovered ? AnyShapeStyle(GlassTheme.pillGlassFill) : AnyShapeStyle(Color.white.opacity(0.06))))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(item.isCompleted ? AnyShapeStyle(GlassTheme.accentEmerald.opacity(0.40)) : AnyShapeStyle(GlassTheme.subtleSpecularBorder), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }
}
