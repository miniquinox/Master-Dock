import Foundation

final class AIServiceMockTests {
    func testMockAIServiceStreaming() async throws {
        let mockService = MockAIService()
        let stream = mockService.sendMessageStream(prompt: "Summarize this article", conversationHistory: [])
        
        var accumulated = ""
        for try await chunk in stream {
            accumulated += chunk
        }
        
        XCTAssertFalse(accumulated.isEmpty)
        XCTAssertTrue(accumulated.contains("summary") || accumulated.contains("Summary") || accumulated.contains("Theme"))
    }
    
    func testAppleIntelligenceStreaming() async throws {
        let aiService = AppleIntelligenceService()
        let stream = aiService.sendMessageStream(prompt: "Hello! Reply with a short greeting.", conversationHistory: [])
        
        var accumulated = ""
        for try await chunk in stream {
            accumulated += chunk
        }
        
        XCTAssertFalse(accumulated.isEmpty)
    }
    
    func testPromptTemplateResolution() {
        let promptService = PromptLibraryService()
        let summarizeAction = PromptAction(
            title: "Summarize",
            iconSystemName: "doc.plaintext",
            promptTemplate: "Summarize the following:\n\n{clipboard}"
        )
        
        let resolved = promptService.resolvePrompt(summarizeAction, clipboardContent: "Apple releases macOS Sequoia with enhanced continuity.")
        XCTAssertTrue(resolved.contains("Apple releases macOS Sequoia"))
        XCTAssertFalse(resolved.contains("{clipboard}"))
    }
    
    @MainActor
    func testChecklistAddTasksIntent() {
        let checklistService = ChecklistService()
        let handler = ChecklistIntentHandler.shared
        
        let initialCount = checklistService.totalCount
        let result = handler.handleIntent(prompt: "Add to my checklist: Prepare pitch deck for investors", checklistService: checklistService)
        
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.didPerformAction == true)
        XCTAssertEqual(checklistService.totalCount, initialCount + 1)
        XCTAssertTrue(checklistService.items.contains(where: { $0.title == "Prepare pitch deck for investors" }))
    }
    
    @MainActor
    func testChecklistCompleteAndClearIntent() {
        let checklistService = ChecklistService()
        let handler = ChecklistIntentHandler.shared
        
        checklistService.addItem(title: "Complete quarterly report")
        let item = checklistService.items.first(where: { $0.title == "Complete quarterly report" })!
        
        let completeResult = handler.handleIntent(prompt: "Mark Complete quarterly report as done", checklistService: checklistService)
        XCTAssertNotNil(completeResult)
        XCTAssertTrue(completeResult?.didPerformAction == true)
        
        let updatedItem = checklistService.items.first(where: { $0.id == item.id })
        XCTAssertTrue(updatedItem?.isCompleted == true)
        
        let clearResult = handler.handleIntent(prompt: "Clear completed tasks from my checklist", checklistService: checklistService)
        XCTAssertNotNil(clearResult)
        XCTAssertTrue(clearResult?.didPerformAction == true)
        XCTAssertFalse(checklistService.items.contains(where: { $0.id == item.id }))
    }
    
    @MainActor
    func testChecklistNaturalLanguagePhrasingIntent() {
        let checklistService = ChecklistService()
        let handler = ChecklistIntentHandler.shared
        
        let result1 = handler.handleIntent(prompt: "add chatting with bange to my list", checklistService: checklistService)
        XCTAssertNotNil(result1)
        XCTAssertTrue(checklistService.items.contains(where: { $0.title == "Chatting with bange" }))
        
        let result2 = handler.handleIntent(prompt: "remind me to fix audio engine on my checklist", checklistService: checklistService)
        XCTAssertNotNil(result2)
        XCTAssertTrue(checklistService.items.contains(where: { $0.title == "Fix audio engine" }))
        
        let result3 = handler.handleIntent(prompt: "put buy organic coffee on my to do list", checklistService: checklistService)
        XCTAssertNotNil(result3)
        XCTAssertTrue(checklistService.items.contains(where: { $0.title == "Buy organic coffee" }))
    }
}
