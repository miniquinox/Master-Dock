import Foundation

public enum GestureDockState: Equatable, Sendable {
    case idle
    case trackingLeftSwipe(progress: Double, velocityX: Double)
    case trackingTopSwipe(progress: Double, velocityY: Double)
    case dockRevealed(mode: DockPresentationMode)
    case dockDismissed
    case voiceModeActive
    case cancelled
}

public enum DockPresentationMode: Equatable, Sendable {
    case standardDock
    case expandedVoice
}

public struct GestureConfiguration: Sendable {
    public var leftEdgeThreshold: Double
    public var topEdgeThreshold: Double
    public var dockCommitThreshold: Double
    public var voiceCommitThreshold: Double
    public var minSwipeVelocity: Double
    
    public static let `default` = GestureConfiguration(
        leftEdgeThreshold: 0.20,      // Leftmost finger within first 20% of trackpad X
        topEdgeThreshold: 0.90,       // Starts within top 10% of trackpad Y
        dockCommitThreshold: 0.18,    // 18% width swipe commits dock open/close
        voiceCommitThreshold: 0.52,   // 52% width swipe commits voice mode
        minSwipeVelocity: 0.15        // Minimum velocity required
    )
}

public final class GestureStateMachine: @unchecked Sendable {
    public private(set) var currentState: GestureDockState = .idle
    public var configuration: GestureConfiguration
    public var isDockOpen: Bool = false
    
    private var initialTouchX: Double = 0
    private var initialTouchY: Double = 0
    private var lastTouchX: Double = 0
    private var lastTouchY: Double = 0
    private var lastTimestamp: Double = 0
    private var isGestureActive = false
    private var activeGestureType: GestureType = .none
    
    private enum GestureType {
        case none
        case leftToRightOpen
        case leftToRightClose
        case topToBottom
    }
    
    public var onStateChange: ((GestureDockState) -> Void)?
    
    public init(configuration: GestureConfiguration = .default) {
        self.configuration = configuration
    }
    
    public func processTouches(
        fingerCount: Int,
        averageX: Double,
        averageY: Double,
        minX: Double? = nil,
        timestamp: Double
    ) {
        // Master Dock triggers specifically on two-finger gestures
        guard fingerCount == 2 else {
            if isGestureActive {
                finishGesture()
            }
            return
        }
        
        let effectiveLeftX = minX ?? averageX
        
        if !isGestureActive {
            // Touch began: check if starting at left edge
            if effectiveLeftX <= configuration.leftEdgeThreshold {
                isGestureActive = true
                if isDockOpen {
                    activeGestureType = .leftToRightClose
                } else {
                    activeGestureType = .leftToRightOpen
                }
                initialTouchX = averageX
                initialTouchY = averageY
                lastTouchX = averageX
                lastTouchY = averageY
                lastTimestamp = timestamp
                if !isDockOpen {
                    updateState(.trackingLeftSwipe(progress: 0.0, velocityX: 0.0))
                }
            } else if !isDockOpen && averageY >= configuration.topEdgeThreshold {
                isGestureActive = true
                activeGestureType = .topToBottom
                initialTouchX = averageX
                initialTouchY = averageY
                lastTouchX = averageX
                lastTouchY = averageY
                lastTimestamp = timestamp
                updateState(.trackingTopSwipe(progress: 0.0, velocityY: 0.0))
            }
            // If touch starts away from the left edge (e.g. effectiveLeftX > 0.20) while dock is open,
            // isGestureActive remains false, allowing completely free vertical scrolling!
            return
        }
        
        // Active gesture ongoing
        let dt = max(timestamp - lastTimestamp, 0.001)
        
        switch activeGestureType {
        case .leftToRightOpen:
            let deltaX = averageX - initialTouchX
            let currentVelocityX = (averageX - lastTouchX) / dt
            let progress = max(0.0, min(1.0, deltaX / 0.8))
            
            lastTouchX = averageX
            lastTouchY = averageY
            lastTimestamp = timestamp
            
            updateState(.trackingLeftSwipe(progress: progress, velocityX: currentVelocityX))
            
        case .leftToRightClose:
            // Tracking left-edge swipe while open to toggle close
            lastTouchX = averageX
            lastTouchY = averageY
            lastTimestamp = timestamp
            
        case .topToBottom:
            let deltaY = initialTouchY - averageY
            let currentVelocityY = (lastTouchY - averageY) / dt
            let progress = max(0.0, min(1.0, deltaY / 0.7))
            
            lastTouchX = averageX
            lastTouchY = averageY
            lastTimestamp = timestamp
            
            updateState(.trackingTopSwipe(progress: progress, velocityY: currentVelocityY))
            
        case .none:
            break
        }
    }
    
    public func finishGesture() {
        guard isGestureActive else { return }
        isGestureActive = false
        
        switch activeGestureType {
        case .leftToRightClose:
            // Swiping from left edge while dock is open immediately closes it!
            isDockOpen = false
            updateState(.dockDismissed)
            updateState(.idle)
            
        case .leftToRightOpen:
            if case .trackingLeftSwipe(let progress, let velocityX) = currentState {
                if progress >= configuration.voiceCommitThreshold {
                    isDockOpen = true
                    updateState(.voiceModeActive)
                } else if progress >= configuration.dockCommitThreshold || (progress >= 0.10 && velocityX > 0.6) {
                    isDockOpen = true
                    updateState(.dockRevealed(mode: .standardDock))
                } else {
                    isDockOpen = false
                    updateState(.cancelled)
                    updateState(.idle)
                }
            } else {
                updateState(.idle)
            }
            
        case .topToBottom:
            if case .trackingTopSwipe(let progress, let velocityY) = currentState {
                if progress >= 0.15 || velocityY > 0.6 {
                    isDockOpen = true
                    updateState(.voiceModeActive)
                } else {
                    isDockOpen = false
                    updateState(.cancelled)
                    updateState(.idle)
                }
            } else {
                updateState(.idle)
            }
            
        case .none:
            updateState(.idle)
        }
        
        activeGestureType = .none
    }
    
    public func resetToIdle() {
        isGestureActive = false
        isDockOpen = false
        activeGestureType = .none
        updateState(.idle)
    }
    
    public func triggerManual(mode: DockPresentationMode) {
        isDockOpen = true
        switch mode {
        case .standardDock:
            updateState(.dockRevealed(mode: .standardDock))
        case .expandedVoice:
            updateState(.voiceModeActive)
        }
    }
    
    private func updateState(_ newState: GestureDockState) {
        currentState = newState
        onStateChange?(newState)
    }
}
