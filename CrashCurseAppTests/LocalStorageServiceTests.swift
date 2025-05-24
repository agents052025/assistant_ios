import XCTest
import CoreData
@testable import CrashCurseApp

class LocalStorageServiceTests: XCTestCase {

    var localStorageService: LocalStorageService!
    var mockPersistentContainer: NSPersistentContainer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Use an in-memory store for testing to avoid polluting the main store
        // and to ensure a clean state for each test.
        mockPersistentContainer = NSPersistentContainer(name: "CrashCurseApp") // Ensure this matches your .xcdatamodeld file name
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType // In-memory store
        description.shouldAddStoreAsynchronously = false // Make it synchronous for testing
        mockPersistentContainer.persistentStoreDescriptions = [description]
        
        mockPersistentContainer.loadPersistentStores { (description, error) in
            // Check if the data store is in memory
            precondition( description.type == NSInMemoryStoreType )

            if let error = error {
                fatalError("Create an in-mem coordinator failed \(error)")
            }
        }
        
        localStorageService = LocalStorageService()
        localStorageService.persistentContainer = mockPersistentContainer // Inject the mock container
    }

    override func tearDownWithError() throws {
        localStorageService = nil
        mockPersistentContainer = nil
        try super.tearDownWithError()
    }

    func testSaveAndFetchChatMessage() {
        // 1. Initial state should be empty
        var messages = localStorageService.fetchChatMessages()
        XCTAssertTrue(messages.isEmpty, "Initially, there should be no chat messages.")
        
        // 2. Save a chat message
        let testContent = "Hello, Test!"
        let testTimestamp = Date()
        let testType = "user"
        
        localStorageService.saveChatMessage(content: testContent, timestamp: testTimestamp, type: testType, agentId: nil, isSenderUser: true)

        // 3. Fetch messages again and verify
        messages = localStorageService.fetchChatMessages()
        XCTAssertEqual(messages.count, 1, "After saving, there should be one chat message.")
        if let message = messages.first {
            XCTAssertEqual(message.content, testContent)
            XCTAssertEqual(message.type, testType)
            XCTAssertTrue(message.isSenderUser)
            XCTAssertNil(message.agentId)
            // Note: We don't check exact timestamp equality because Core Data might not preserve exact nanoseconds
            let secondsDiff = message.timestamp!.timeIntervalSince(testTimestamp)
            XCTAssertLessThan(abs(secondsDiff), 0.001, "Timestamps should be approximately equal")
        } else {
            XCTFail("Couldn't fetch the saved message")
        }
    }
    
    func testSaveAndFetchEvent() {
        // 1. Initial state should be empty
        var events = localStorageService.fetchEvents()
        XCTAssertTrue(events.isEmpty, "Initially, there should be no events.")
        
        // 2. Save an event
        let testTitle = "Test Event"
        let testStartDate = Date()
        let testEndDate = Date().addingTimeInterval(3600) // 1 hour later
        let testLocation = "Test Location"
        let testNotes = "Event notes"
        
        let savedEvent = localStorageService.saveEvent(
            title: testTitle,
            startDate: testStartDate,
            endDate: testEndDate,
            location: testLocation,
            notes: testNotes
        )
        
        XCTAssertNotNil(savedEvent, "Event should be saved and returned")
        
        // 3. Fetch events and verify
        events = localStorageService.fetchEvents()
        XCTAssertEqual(events.count, 1, "After saving, there should be one event.")
        if let event = events.first {
            XCTAssertEqual(event.title, testTitle)
            XCTAssertEqual(event.location, testLocation)
            XCTAssertEqual(event.notes, testNotes)
            XCTAssertFalse(event.isReminderSet)
            
            // Check dates (allowing small differences due to Core Data storage)
            let startDiff = event.startDate!.timeIntervalSince(testStartDate)
            XCTAssertLessThan(abs(startDiff), 0.001, "Start dates should be approximately equal")
            
            let endDiff = event.endDate!.timeIntervalSince(testEndDate)
            XCTAssertLessThan(abs(endDiff), 0.001, "End dates should be approximately equal")
        } else {
            XCTFail("Couldn't fetch the saved event")
        }
    }
    
    func testSaveAndFetchTask() {
        // 1. Initial state should be empty
        var tasks = localStorageService.fetchTasks()
        XCTAssertTrue(tasks.isEmpty, "Initially, there should be no tasks.")
        
        // 2. Save a task
        let testDescription = "Test Task"
        let testDueDate = Date().addingTimeInterval(86400) // Due tomorrow
        
        let savedTask = localStorageService.saveTask(description: testDescription, dueDate: testDueDate)
        XCTAssertNotNil(savedTask, "Task should be saved and returned")
        
        // 3. Fetch tasks and verify
        tasks = localStorageService.fetchTasks()
        XCTAssertEqual(tasks.count, 1, "After saving, there should be one task.")
        if let task = tasks.first {
            XCTAssertEqual(task.taskDescription, testDescription)
            XCTAssertFalse(task.isCompleted)
            
            // Check due date (allowing small differences due to Core Data storage)
            let dueDiff = task.dueDate!.timeIntervalSince(testDueDate)
            XCTAssertLessThan(abs(dueDiff), 0.001, "Due dates should be approximately equal")
            
            // Creation date should be within the last few seconds
            let now = Date()
            let creationDiff = now.timeIntervalSince(task.creationDate!)
            XCTAssertGreaterThanOrEqual(creationDiff, 0, "Creation date should be in the past")
            XCTAssertLessThan(creationDiff, 10, "Creation date should be recent (within 10 seconds)")
        } else {
            XCTFail("Couldn't fetch the saved task")
        }
    }
    
    func testSaveAndFetchPreference() {
        // 1. Initially, preference should not exist
        let testKey = "testPreferenceKey"
        let fetchedValue = localStorageService.fetchPreference(forKey: testKey)
        XCTAssertNil(fetchedValue, "Initially, the preference should not exist")
        
        // 2. Save a preference
        let testValue = "testPreferenceValue"
        localStorageService.savePreference(key: testKey, value: testValue)
        
        // 3. Fetch and verify
        let fetchedAfterSave = localStorageService.fetchPreference(forKey: testKey)
        XCTAssertEqual(fetchedAfterSave, testValue)
        
        // 4. Update the preference
        let updatedValue = "updatedValue"
        localStorageService.savePreference(key: testKey, value: updatedValue)
        
        // 5. Fetch and verify update
        let fetchedAfterUpdate = localStorageService.fetchPreference(forKey: testKey)
        XCTAssertEqual(fetchedAfterUpdate, updatedValue)
    }
    
    func testSaveAndFetchAgentConfiguration() {
        // 1. Initial state should be empty
        var configs = localStorageService.fetchAgentConfigurations()
        XCTAssertTrue(configs.isEmpty, "Initially, there should be no agent configurations.")
        
        // 2. Save a configuration
        let testAgentId = "test_agent_1"
        let testName = "Test Agent"
        let testSettings = "{\"key\": \"value\"}"
        
        let savedConfig = localStorageService.saveAgentConfiguration(
            agentId: testAgentId,
            name: testName,
            settings: testSettings,
            isEnabled: true
        )
        
        XCTAssertNotNil(savedConfig, "Configuration should be saved and returned")
        
        // 3. Fetch and verify
        configs = localStorageService.fetchAgentConfigurations()
        XCTAssertEqual(configs.count, 1, "After saving, there should be one configuration.")
        if let config = configs.first {
            XCTAssertEqual(config.agentId, testAgentId)
            XCTAssertEqual(config.name, testName)
            XCTAssertEqual(config.settings, testSettings)
            XCTAssertTrue(config.isEnabled)
        } else {
            XCTFail("Couldn't fetch the saved configuration")
        }
        
        // 4. Update configuration
        let updatedName = "Updated Agent Name"
        let updatedEnabled = false
        
        let updatedConfig = localStorageService.saveAgentConfiguration(
            agentId: testAgentId,
            name: updatedName,
            settings: testSettings,
            isEnabled: updatedEnabled
        )
        
        XCTAssertNotNil(updatedConfig, "Updated configuration should be returned")
        
        // 5. Fetch and verify update
        configs = localStorageService.fetchAgentConfigurations()
        XCTAssertEqual(configs.count, 1, "Should still have just one configuration.")
        if let config = configs.first {
            XCTAssertEqual(config.agentId, testAgentId)
            XCTAssertEqual(config.name, updatedName)
            XCTAssertFalse(config.isEnabled)
        } else {
            XCTFail("Couldn't fetch the updated configuration")
        }
    }
} 