import Foundation
import AppKit
import AVFoundation
import EventKit

public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    @Published public private(set) var isAccessibilityGranted: Bool = false
    @Published public private(set) var isMicrophoneGranted: Bool = false
    @Published public private(set) var isCalendarGranted: Bool = false
    
    public init() {
        checkAllPermissions()
    }
    
    public func checkAllPermissions() {
        checkAccessibility()
        checkMicrophone()
        checkCalendar()
    }
    
    public func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        DispatchQueue.main.async {
            self.isAccessibilityGranted = trusted
        }
    }
    
    public func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.async {
            self.isAccessibilityGranted = trusted
        }
    }
    
    public func checkMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            self.isMicrophoneGranted = true
        default:
            self.isMicrophoneGranted = false
        }
    }
    
    public func requestMicrophone(completion: @escaping (Bool) -> Void = { _ in }) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.isMicrophoneGranted = granted
                completion(granted)
            }
        }
    }
    
    public func checkCalendar() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            self.isCalendarGranted = (status == .fullAccess || status == .writeOnly)
        } else {
            self.isCalendarGranted = (status == .authorized)
        }
    }
    
    public func requestCalendar(store: EKEventStore = EKEventStore(), completion: @escaping (Bool) -> Void = { _ in }) {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.isCalendarGranted = granted
                    completion(granted)
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.isCalendarGranted = granted
                    completion(granted)
                }
            }
        }
    }
    
    public func openSystemSettings(for type: PermissionType) {
        let urlString: String
        switch type {
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .calendar:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        case .automation:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    public enum PermissionType {
        case accessibility
        case microphone
        case calendar
        case automation
    }
}
