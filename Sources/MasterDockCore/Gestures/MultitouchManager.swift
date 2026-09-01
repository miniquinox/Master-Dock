import Foundation
import AppKit
import Combine
import MasterDockMultitouchC

public final class MultitouchManager: ObservableObject {
    public static let shared = MultitouchManager()
    
    public let stateMachine: GestureStateMachine
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var isRunning = false
    
    @Published public private(set) var currentState: GestureDockState = .idle
    @Published public private(set) var isMultitouchSupported: Bool = false
    
    public init(configuration: GestureConfiguration = .default) {
        self.stateMachine = GestureStateMachine(configuration: configuration)
        self.stateMachine.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.currentState = state
            }
        }
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        
        isMultitouchSupported = MDMultitouchIsAvailable()
        
        if isMultitouchSupported {
            let context = Unmanaged.passUnretained(self).toOpaque()
            let started = MDMultitouchStartListening({ touches, count, timestamp, ctx in
                guard let ctx = ctx, count > 0, let touches = touches else { return }
                let manager = Unmanaged<MultitouchManager>.fromOpaque(ctx).takeUnretainedValue()
                
                // Count active touching fingers
                var activeTouches: [MTTouch] = []
                for i in 0..<Int(count) {
                    let touch = touches[i]
                    if touch.state == MTTouchStateTouching || touch.state == MTTouchStateMakeTouch {
                        activeTouches.append(touch)
                    }
                }
                
                if activeTouches.count == 1 {
                    let x = Double(activeTouches[0].normalizedPosition.position.x)
                    let y = Double(activeTouches[0].normalizedPosition.position.y)
                    manager.stateMachine.processTouches(
                        fingerCount: 1,
                        averageX: x,
                        averageY: y,
                        minX: x,
                        timestamp: timestamp
                    )
                } else if activeTouches.count == 2 {
                    let minX = Double(min(activeTouches[0].normalizedPosition.position.x, activeTouches[1].normalizedPosition.position.x))
                    let avgX = Double(activeTouches[0].normalizedPosition.position.x + activeTouches[1].normalizedPosition.position.x) / 2.0
                    let avgY = Double(activeTouches[0].normalizedPosition.position.y + activeTouches[1].normalizedPosition.position.y) / 2.0
                    manager.stateMachine.processTouches(
                        fingerCount: 2,
                        averageX: avgX,
                        averageY: avgY,
                        minX: minX,
                        timestamp: timestamp
                    )
                } else if activeTouches.isEmpty {
                    manager.stateMachine.finishGesture()
                } else {
                    manager.stateMachine.finishGesture()
                }
            }, context)
            
            if !started {
                print("[MultitouchManager] Notice: Multitouch hardware callback initialization fell back to hotkeys.")
            }
        }
        
        setupHotkeyFallbacks()
    }
    
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        
        MDMultitouchStopListening()
        
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
    
    private func setupHotkeyFallbacks() {
        // Option + Space -> Standard Master Dock
        // Option + Shift + Space -> AI Voice Mode
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume event
            }
            return event
        }
    }
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Spacebar is keyCode 49
        guard event.keyCode == 49 else { return false }
        
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        if flags == [.option] {
            // Option + Space -> Toggle standard dock
            DispatchQueue.main.async { [weak self] in
                if self?.currentState == .dockRevealed(mode: .standardDock) {
                    self?.stateMachine.resetToIdle()
                } else {
                    self?.stateMachine.triggerManual(mode: .standardDock)
                }
            }
            return true
        } else if flags == [.option, .shift] {
            // Option + Shift + Space -> Toggle AI Voice Mode
            DispatchQueue.main.async { [weak self] in
                if self?.currentState == .voiceModeActive {
                    self?.stateMachine.resetToIdle()
                } else {
                    self?.stateMachine.triggerManual(mode: .expandedVoice)
                }
            }
            return true
        }
        
        return false
    }
}
