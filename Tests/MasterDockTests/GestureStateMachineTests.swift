import Foundation

final class GestureStateMachineTests {
    var stateMachine: GestureStateMachine!
    
    func setUp() {
        stateMachine = GestureStateMachine(configuration: .default)
    }
    
    func testInitialStateIsIdle() {
        XCTAssertEqual(stateMachine.currentState, .idle)
    }
    
    func testLeftEdgeSequentialSwipeStartsTracking() {
        var recordedStates: [GestureDockState] = []
        stateMachine.onStateChange = { state in
            recordedStates.append(state)
        }
        
        // Step 1: 1 finger touches down at extreme left edge (x = 0.03)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.03, averageY: 0.5, timestamp: 1.00)
        XCTAssertEqual(stateMachine.currentState, .idle)
        
        // Step 2: 1 finger slides inward (x = 0.05, delta = 0.02 >= 0.015)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.05, averageY: 0.5, timestamp: 1.03)
        XCTAssertEqual(stateMachine.currentState, .idle)
        
        // Step 3: 2nd finger joins trackpad in motion (avgX = 0.07, minX = 0.04)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.07, averageY: 0.5, minX: 0.04, timestamp: 1.06)
        
        XCTAssertEqual(recordedStates.count, 1)
        if case .trackingLeftSwipe(let progress, _) = stateMachine.currentState {
            XCTAssertEqual(progress, 0.05, accuracy: 0.05)
        } else {
            XCTFail("Expected trackingLeftSwipe state")
        }
    }
    
    func testDirectTwoFingerTouchIgnored() {
        // 2 fingers land simultaneously at left edge without 1-finger sliding start
        stateMachine.processTouches(fingerCount: 2, averageX: 0.03, averageY: 0.5, minX: 0.03, timestamp: 1.0)
        XCTAssertEqual(stateMachine.currentState, .idle)
    }
    
    func testTouchNotAtExtremeEdgeIgnored() {
        // 1 finger starts slightly inward (x = 0.06 > leftEdgeThreshold 0.035)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.06, averageY: 0.5, timestamp: 1.00)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.08, averageY: 0.5, timestamp: 1.03)
        // 2nd finger joins
        stateMachine.processTouches(fingerCount: 2, averageX: 0.09, averageY: 0.5, minX: 0.07, timestamp: 1.06)
        XCTAssertEqual(stateMachine.currentState, .idle)
    }
    
    func testTwoFingerTouchWithZeroSlideDistanceIgnored() {
        // 1 finger touches down at left edge for 1 frame
        stateMachine.processTouches(fingerCount: 1, averageX: 0.03, averageY: 0.5, timestamp: 1.00)
        // 2nd finger immediately lands without 1st finger having slid
        stateMachine.processTouches(fingerCount: 2, averageX: 0.04, averageY: 0.5, minX: 0.03, timestamp: 1.01)
        XCTAssertEqual(stateMachine.currentState, .idle)
    }
    
    func testSingleFingerInMiddleThenSecondFingerIgnored() {
        // 1 finger starts in the middle of trackpad (x = 0.50)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.50, averageY: 0.5, timestamp: 1.00)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.53, averageY: 0.5, timestamp: 1.03)
        // 2nd finger joins
        stateMachine.processTouches(fingerCount: 2, averageX: 0.54, averageY: 0.5, minX: 0.50, timestamp: 1.06)
        XCTAssertEqual(stateMachine.currentState, .idle)
    }
    
    func testDelayedSecondFingerIgnored() {
        // 1 finger at left edge slides
        stateMachine.processTouches(fingerCount: 1, averageX: 0.03, averageY: 0.5, timestamp: 1.00)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.06, averageY: 0.5, timestamp: 1.03)
        // 2nd finger joins too late (> 0.45s)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.10, averageY: 0.5, minX: 0.05, timestamp: 1.70)
        XCTAssertEqual(stateMachine.currentState, .idle)
    }
    
    func testSingleFingerDragIgnored() {
        // 1 finger starts at edge and drags across screen (drag and drop)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.03, averageY: 0.5, timestamp: 1.00)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.10, averageY: 0.5, timestamp: 1.05)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.35, averageY: 0.5, timestamp: 1.20)
        stateMachine.finishGesture()
        XCTAssertEqual(stateMachine.currentState, .idle)
    }
    
    func testLeftEdgeSwipeProgressAndCommitStandardDock() {
        // 1 finger starts at left edge and slides
        stateMachine.processTouches(fingerCount: 1, averageX: 0.03, averageY: 0.5, timestamp: 1.00)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.05, averageY: 0.5, timestamp: 1.03)
        // 2nd finger joins
        stateMachine.processTouches(fingerCount: 2, averageX: 0.07, averageY: 0.5, minX: 0.04, timestamp: 1.06)
        
        // Move horizontally to x = 0.15 (delta = 0.12, progress ~ 0.55 >= 0.50 commit threshold)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.18, averageY: 0.5, minX: 0.15, timestamp: 1.15)
        
        if case .trackingLeftSwipe(let progress, _) = stateMachine.currentState {
            XCTAssertGreaterThan(progress, 0.50)
        } else {
            XCTFail("Expected trackingLeftSwipe")
        }
        
        // Lift fingers -> should commit standard dock
        stateMachine.finishGesture()
        XCTAssertEqual(stateMachine.currentState, .dockRevealed(mode: .standardDock))
    }
    
    func testLeftFingerAt25PercentReachesMaxOpenProgress() {
        // 1 finger starts at left edge and slides
        stateMachine.processTouches(fingerCount: 1, averageX: 0.03, averageY: 0.5, timestamp: 1.00)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.05, averageY: 0.5, timestamp: 1.03)
        // 2nd finger joins
        stateMachine.processTouches(fingerCount: 2, averageX: 0.07, averageY: 0.5, minX: 0.04, timestamp: 1.06)
        
        // Move horizontally until left finger reaches 25% of mousepad (minX = 0.25)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.28, averageY: 0.5, minX: 0.25, timestamp: 1.15)
        
        if case .trackingLeftSwipe(let progress, _) = stateMachine.currentState {
            XCTAssertGreaterThan(progress, 0.99)
        } else {
            XCTFail("Expected trackingLeftSwipe with progress >= 1.0")
        }
    }
    
    func testLeftEdgeSwipePastHalfCommitsVoiceMode() {
        // 1 finger starts at left edge and slides
        stateMachine.processTouches(fingerCount: 1, averageX: 0.03, averageY: 0.5, timestamp: 1.00)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.05, averageY: 0.5, timestamp: 1.03)
        // 2nd finger joins
        stateMachine.processTouches(fingerCount: 2, averageX: 0.07, averageY: 0.5, minX: 0.04, timestamp: 1.06)
        
        // Move horizontally across trackpad past 55%
        stateMachine.processTouches(fingerCount: 2, averageX: 0.55, averageY: 0.5, timestamp: 1.20)
        
        stateMachine.finishGesture()
        XCTAssertEqual(stateMachine.currentState, .voiceModeActive)
    }
    
    func testTopEdgeTwoFingerSwipeCommitsVoiceMode() {
        // Touch down at top edge (y = 0.95)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.5, averageY: 0.95, timestamp: 1.0)
        
        // Swipe downward
        stateMachine.processTouches(fingerCount: 2, averageX: 0.5, averageY: 0.70, timestamp: 1.1)
        
        stateMachine.finishGesture()
        XCTAssertEqual(stateMachine.currentState, .voiceModeActive)
    }
    
    func testLeftEdgeSwipeWhileOpenClosesDock() {
        // Open the dock first
        stateMachine.triggerManual(mode: .standardDock)
        XCTAssertTrue(stateMachine.isDockOpen)
        
        // Swipe from left edge while open: 1 finger slides then 2 fingers join
        stateMachine.processTouches(fingerCount: 1, averageX: 0.03, averageY: 0.5, timestamp: 1.00)
        stateMachine.processTouches(fingerCount: 1, averageX: 0.05, averageY: 0.5, timestamp: 1.03)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.07, averageY: 0.5, minX: 0.04, timestamp: 1.06)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.25, averageY: 0.5, timestamp: 1.15)
        stateMachine.finishGesture()
        
        XCTAssertFalse(stateMachine.isDockOpen)
        XCTAssertEqual(stateMachine.currentState, .idle)
    }
    
    func testScrollingWhileOpenLeavesDockOpen() {
        // Open the dock
        stateMachine.triggerManual(mode: .standardDock)
        XCTAssertTrue(stateMachine.isDockOpen)
        
        // Direct 2-finger touch down in the middle of trackpad (x = 0.5) to scroll vertically
        stateMachine.processTouches(fingerCount: 2, averageX: 0.5, averageY: 0.6, timestamp: 1.0)
        stateMachine.processTouches(fingerCount: 2, averageX: 0.5, averageY: 0.4, timestamp: 1.1)
        stateMachine.finishGesture()
        
        // Dock should remain open!
        XCTAssertTrue(stateMachine.isDockOpen)
    }
}
