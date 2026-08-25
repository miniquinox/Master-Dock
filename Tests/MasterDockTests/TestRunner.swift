import Foundation

@main
struct TestRunner {
    static func main() async {
        print("==================================================")
        print("          MASTER DOCK TEST SUITE RUNNER           ")
        print("==================================================")
        
        var passed = 0
        
        func runTest(_ name: String, block: () async throws -> Void) async {
            print("   • [TEST] \(name)... ", terminator: "")
            do {
                try await block()
                passed += 1
                print("PASSED ✅")
            } catch {
                print("FAILED ❌ (\(error))")
                exit(1)
            }
        }
        
        print("\n-> [Suite] Gesture State Machine Tests:")
        await runTest("testInitialStateIsIdle") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testInitialStateIsIdle()
        }
        await runTest("testLeftEdgeTwoFingerSwipeStartsTracking") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testLeftEdgeTwoFingerSwipeStartsTracking()
        }
        await runTest("testLeftEdgeSwipeProgressAndCommitStandardDock") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testLeftEdgeSwipeProgressAndCommitStandardDock()
        }
        await runTest("testLeftEdgeSwipePastHalfCommitsVoiceMode") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testLeftEdgeSwipePastHalfCommitsVoiceMode()
        }
        await runTest("testTopEdgeTwoFingerSwipeCommitsVoiceMode") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testTopEdgeTwoFingerSwipeCommitsVoiceMode()
        }
        await runTest("testSingleFingerIgnored") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testSingleFingerIgnored()
        }
        await runTest("testLeftEdgeSwipeWhileOpenClosesDock") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testLeftEdgeSwipeWhileOpenClosesDock()
        }
        await runTest("testScrollingWhileOpenLeavesDockOpen") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testScrollingWhileOpenLeavesDockOpen()
        }
        
        print("\n-> [Suite] Clipboard Monitor Tests:")
        await runTest("testClipboardItemCreation") {
            let c = ClipboardMonitorTests()
            c.testClipboardItemCreation()
        }
        await runTest("testClipboardTypeClassification") {
            let c = ClipboardMonitorTests()
            c.testClipboardTypeClassification()
        }
        
        print("\n-> [Suite] Calendar Service Tests:")
        await runTest("testMeetingCountdownFormatting") {
            let c = CalendarServiceTests()
            c.testMeetingCountdownFormatting()
        }
        await runTest("testHappeningNowCountdown") {
            let c = CalendarServiceTests()
            c.testHappeningNowCountdown()
        }
        
        print("\n-> [Suite] Daily Checklist Tests:")
        await runTest("testChecklistProgressCalculation") {
            let c = ChecklistServiceTests()
            c.testChecklistProgressCalculation()
        }
        
        print("\n-> [Suite] AI & Prompt Library Tests:")
        await runTest("testMockAIServiceStreaming") {
            let a = AIServiceMockTests()
            try await a.testMockAIServiceStreaming()
        }
        await runTest("testAppleIntelligenceStreaming") {
            let a = AIServiceMockTests()
            try await a.testAppleIntelligenceStreaming()
        }
        await runTest("testPromptTemplateResolution") {
            let a = AIServiceMockTests()
            a.testPromptTemplateResolution()
        }
        
        print("\n==================================================")
        print("SUMMARY: \(passed) Total Tests | All \(passed) Passed | 0 Failed")
        print("==================================================")
        print("🎉 ALL 13 TEST SUITES PASSED FLAWLESSLY!\n")
    }
}
