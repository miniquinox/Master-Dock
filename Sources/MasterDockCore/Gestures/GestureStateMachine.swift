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
    public var leftEdgeThreshold: Double              // Initial 1st finger must land within this X from extreme left edge (0.0 - 1.0)
    public var minSingleFingerSlideDistance: Double   // Min distance 1st finger must slide right before 2nd finger joins
    public var minSingleFingerFrames: Int             // Min touch frames observed with single finger
    public var maxFingerJoinDelay: Double             // Max seconds between 1st finger touch and 2nd finger join
    public var maxJoinDistanceX: Double               // Max X coordinate touches can reach before 2nd finger joins
    public var maxOpenDistanceX: Double               // Left finger X coordinate where dock reaches 100% max open
    public var topEdgeThreshold: Double               // Starts within top 10% of trackpad Y
    public var dockCommitThreshold: Double            // Progress needed to commit standard dock (0.50)
    public var voiceCommitThreshold: Double           // Progress needed to commit voice mode (1.60)
    public var minSwipeVelocity: Double               // Minimum velocity required
    
    public static let `default` = GestureConfiguration(
        leftEdgeThreshold: 0.035,            // First finger must touch down at the extreme left edge (<= 3.5% X)
        minSingleFingerSlideDistance: 0.010, // First finger must physically slide inward >= 1.0% trackpad width
        minSingleFingerFrames: 2,            // Must observe at least 2 distinct frames of 1-finger sliding
        maxFingerJoinDelay: 0.45,            // Second finger must join within 450ms
        maxJoinDistanceX: 0.20,              // Fingers must still be near left edge region (<= 20% X) when 2nd finger joins
        maxOpenDistanceX: 0.25,              // Max open position reached as left finger reaches 25% of trackpad X
        topEdgeThreshold: 0.90,              // Starts within top 10% of trackpad Y
        dockCommitThreshold: 0.50,           // 50% open progress (~12.5% trackpad X) commits dock to open
        voiceCommitThreshold: 1.60,          // Swiping past ~40% trackpad X commits voice mode
        minSwipeVelocity: 0.15               // Minimum velocity required
    )
    
    public init(
        leftEdgeThreshold: Double = 0.035,
        minSingleFingerSlideDistance: Double = 0.010,
        minSingleFingerFrames: Int = 2,
        maxFingerJoinDelay: Double = 0.45,
        maxJoinDistanceX: Double = 0.20,
        maxOpenDistanceX: Double = 0.25,
        topEdgeThreshold: Double = 0.90,
        dockCommitThreshold: Double = 0.50,
        voiceCommitThreshold: Double = 1.60,
        minSwipeVelocity: Double = 0.15
    ) {
        self.leftEdgeThreshold = leftEdgeThreshold
        self.minSingleFingerSlideDistance = minSingleFingerSlideDistance
        self.minSingleFingerFrames = minSingleFingerFrames
        self.maxFingerJoinDelay = maxFingerJoinDelay
        self.maxJoinDistanceX = maxJoinDistanceX
        self.maxOpenDistanceX = maxOpenDistanceX
        self.topEdgeThreshold = topEdgeThreshold
        self.dockCommitThreshold = dockCommitThreshold
        self.voiceCommitThreshold = voiceCommitThreshold
        self.minSwipeVelocity = minSwipeVelocity
    }
}

public final class GestureStateMachine: @unchecked Sendable {
    public private(set) var currentState: GestureDockState = .idle
    public var configuration: GestureConfiguration
    public var isDockOpen: Bool = false
    
    // Strict 1-finger edge entry candidate tracking
    private var isEdgeCandidate: Bool = false
    private var candidateStartX: Double = 0
    private var candidateStartY: Double = 0
    private var candidateStartTime: Double = 0
    private var candidateLastX: Double = 0
    private var candidateFrames: Int = 0
    private var candidateHasSlid: Bool = false
    
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
        let touchX = minX ?? averageX
        
        // Single finger touch: check for edge swipe initiation candidate
        if fingerCount == 1 {
            if isGestureActive {
                // If fingers lift down to 1 during active 2-finger swipe, finish gesture
                finishGesture()
                return
            }
            
            if !isEdgeCandidate {
                // 1st finger touching down: must be at extreme left edge
                if touchX <= configuration.leftEdgeThreshold {
                    isEdgeCandidate = true
                    candidateStartX = touchX
                    candidateStartY = averageY
                    candidateStartTime = timestamp
                    candidateLastX = touchX
                    candidateFrames = 1
                    candidateHasSlid = false
                }
            } else {
                // 1st finger already active, moving inward:
                candidateFrames += 1
                let slideDeltaX = touchX - candidateStartX
                let timeElapsed = timestamp - candidateStartTime
                
                // Confirm that the single finger has established a rightward sliding motion
                if slideDeltaX >= configuration.minSingleFingerSlideDistance && candidateFrames >= configuration.minSingleFingerFrames {
                    candidateHasSlid = true
                }
                
                // Invalidate candidate if finger moves backwards, moves excessively vertically, times out, or moves too far inward without a 2nd finger
                let deltaY = abs(averageY - candidateStartY)
                if slideDeltaX < -0.02 || deltaY > 0.30 || timeElapsed > configuration.maxFingerJoinDelay || touchX > configuration.maxJoinDistanceX {
                    isEdgeCandidate = false
                    candidateHasSlid = false
                }
                
                candidateLastX = touchX
            }
            return
        }
        
        // Two fingers active
        if fingerCount == 2 {
            if !isGestureActive {
                // Check if 2-finger gesture originated from a 1-finger left edge entry candidate
                // ONLY accept if a single finger started at the left edge AND actually slid rightward BEFORE the second finger joined!
                let timeElapsed = timestamp - candidateStartTime
                let isValidSequentialEdgeSwipe = isEdgeCandidate &&
                                                 candidateHasSlid &&
                                                 timeElapsed <= configuration.maxFingerJoinDelay &&
                                                 touchX <= configuration.maxJoinDistanceX
                
                if isValidSequentialEdgeSwipe {
                    isGestureActive = true
                    isEdgeCandidate = false
                    candidateHasSlid = false
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
                        let leftFingerX = minX ?? averageX
                        let travelSpan = max(configuration.maxOpenDistanceX - candidateStartX, 0.15)
                        let deltaX = max(0.0, leftFingerX - candidateStartX)
                        let initialProgress = max(0.0, deltaX / travelSpan)
                        updateState(.trackingLeftSwipe(progress: initialProgress, velocityX: 0.0))
                    }
                } else if !isDockOpen && averageY >= configuration.topEdgeThreshold {
                    // Top edge swipe for Voice Mode
                    isGestureActive = true
                    isEdgeCandidate = false
                    candidateHasSlid = false
                    activeGestureType = .topToBottom
                    initialTouchX = averageX
                    initialTouchY = averageY
                    lastTouchX = averageX
                    lastTouchY = averageY
                    lastTimestamp = timestamp
                    updateState(.trackingTopSwipe(progress: 0.0, velocityY: 0.0))
                } else {
                    // Two fingers touched down without a single finger sliding first!
                    // Reset candidate and ignore completely (prevents accidental triggers during 2-finger scrolling, taps, etc.)
                    isEdgeCandidate = false
                    candidateHasSlid = false
                }
                return
            }
            
            // Active gesture ongoing
            let dt = max(timestamp - lastTimestamp, 0.001)
            
            switch activeGestureType {
            case .leftToRightOpen:
                let leftFingerX = minX ?? averageX
                let travelSpan = max(configuration.maxOpenDistanceX - candidateStartX, 0.15)
                let deltaX = max(0.0, leftFingerX - candidateStartX)
                let currentVelocityX = (averageX - lastTouchX) / dt
                let progress = max(0.0, deltaX / travelSpan)
                
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
            return
        }
        
        // Any other finger count (0 or > 2)
        if isGestureActive {
            finishGesture()
        }
        isEdgeCandidate = false
        candidateHasSlid = false
        candidateFrames = 0
    }
    
    public func finishGesture() {
        isEdgeCandidate = false
        candidateHasSlid = false
        candidateFrames = 0
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
                } else if progress >= configuration.dockCommitThreshold || (progress >= 0.35 && velocityX > 0.6) {
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
        isEdgeCandidate = false
        candidateHasSlid = false
        candidateFrames = 0
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
