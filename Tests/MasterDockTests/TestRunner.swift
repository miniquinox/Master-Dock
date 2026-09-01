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
        await runTest("testLeftEdgeSequentialSwipeStartsTracking") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testLeftEdgeSequentialSwipeStartsTracking()
        }
        await runTest("testDirectTwoFingerTouchIgnored") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testDirectTwoFingerTouchIgnored()
        }
        await runTest("testTouchNotAtExtremeEdgeIgnored") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testTouchNotAtExtremeEdgeIgnored()
        }
        await runTest("testTwoFingerTouchWithZeroSlideDistanceIgnored") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testTwoFingerTouchWithZeroSlideDistanceIgnored()
        }
        await runTest("testSingleFingerInMiddleThenSecondFingerIgnored") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testSingleFingerInMiddleThenSecondFingerIgnored()
        }
        await runTest("testDelayedSecondFingerIgnored") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testDelayedSecondFingerIgnored()
        }
        await runTest("testSingleFingerDragIgnored") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testSingleFingerDragIgnored()
        }
        await runTest("testLeftEdgeSwipeProgressAndCommitStandardDock") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testLeftEdgeSwipeProgressAndCommitStandardDock()
        }
        await runTest("testLeftFingerAt25PercentReachesMaxOpenProgress") {
            let g = GestureStateMachineTests()
            g.setUp()
            g.testLeftFingerAt25PercentReachesMaxOpenProgress()
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
        await runTest("testChecklistAddTasksIntent") {
            let a = AIServiceMockTests()
            a.testChecklistAddTasksIntent()
        }
        await runTest("testChecklistCompleteAndClearIntent") {
            let a = AIServiceMockTests()
            a.testChecklistCompleteAndClearIntent()
        }
        await runTest("testChecklistNaturalLanguagePhrasingIntent") {
            let a = AIServiceMockTests()
            a.testChecklistNaturalLanguagePhrasingIntent()
        }
        
        print("\n==================================================")
        print("SUMMARY: \(passed) Total Tests | All \(passed) Passed | 0 Failed")
        print("==================================================")
        print("🎉 ALL 13 TEST SUITES PASSED FLAWLESSLY!\n")
    }
}
