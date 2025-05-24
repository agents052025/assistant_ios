import Foundation
import CoreData
import Combine

class LocalStorageService {
    // MARK: - Core Data stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "CrashCurseApp") // Ensure this matches your .xcdatamodeld file name
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate.
                // You should not use this function in a shipping application, although it may be useful during development.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    // MARK: - Core Data Saving support
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    // MARK: - ChatMessage Methods with Combine
    func fetchMessages() -> AnyPublisher<[ChatMessage], Error> {
        return Future<[ChatMessage], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "LocalStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<ChatMessage>(entityName: "ChatMessage")
            
            // Sort by timestamp, oldest first (for chat flow)
            let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: true)
            fetchRequest.sortDescriptors = [sortDescriptor]
            
            do {
                let messages = try context.fetch(fetchRequest)
                promise(.success(messages))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // Legacy method for backward compatibility
    func fetchChatMessages() -> [ChatMessage] {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<ChatMessage>(entityName: "ChatMessage")
        
        // Default sort by timestamp, newest first
        let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching chat messages: \(error)")
            return []
        }
    }

    func saveChatMessage(content: String, timestamp: Date, type: String, agentId: String? = nil, isSenderUser: Bool = false) {
        let context = persistentContainer.viewContext
        
        if let chatMessage = NSEntityDescription.insertNewObject(forEntityName: "ChatMessage", into: context) as? ChatMessage {
            chatMessage.id = UUID()
            chatMessage.content = content
            chatMessage.timestamp = timestamp
            chatMessage.type = type
            chatMessage.agentId = agentId
            chatMessage.isSenderUser = isSenderUser
            
            saveContext()
        }
    }
    
    // MARK: - EventEntity Methods with Combine
    func fetchEvents() -> AnyPublisher<[EventEntity], Error> {
        return Future<[EventEntity], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "LocalStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<EventEntity>(entityName: "EventEntity")
            
            // Default sort by startDate, soonest first
            let sortDescriptor = NSSortDescriptor(key: "startDate", ascending: true)
            fetchRequest.sortDescriptors = [sortDescriptor]
            
            do {
                let events = try context.fetch(fetchRequest)
                promise(.success(events))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // Legacy method for backward compatibility
    func fetchEventsSync() -> [EventEntity] {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<EventEntity>(entityName: "EventEntity")
        
        // Default sort by startDate, soonest first
        let sortDescriptor = NSSortDescriptor(key: "startDate", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching events: \(error)")
            return []
        }
    }
    
    func saveEvent(title: String, startDate: Date, endDate: Date? = nil, location: String? = nil, notes: String? = nil) -> EventEntity? {
        let context = persistentContainer.viewContext
        
        if let event = NSEntityDescription.insertNewObject(forEntityName: "EventEntity", into: context) as? EventEntity {
            event.id = UUID()
            event.title = title
            event.startDate = startDate
            event.endDate = endDate
            event.location = location
            event.notes = notes
            event.isReminderSet = false
            
            saveContext()
            return event
        }
        return nil
    }
    
    // MARK: - UserTask Methods with Combine
    func fetchTasks() -> AnyPublisher<[UserTask], Error> {
        return Future<[UserTask], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "LocalStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<UserTask>(entityName: "UserTask")
            
            // Default sort by dueDate, soonest first, then by creationDate, newest first
            let dueDateSort = NSSortDescriptor(key: "dueDate", ascending: true)
            let creationDateSort = NSSortDescriptor(key: "creationDate", ascending: false)
            fetchRequest.sortDescriptors = [dueDateSort, creationDateSort]
            
            do {
                let tasks = try context.fetch(fetchRequest)
                promise(.success(tasks))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // Legacy method for backward compatibility
    func fetchTasksSync() -> [UserTask] {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<UserTask>(entityName: "UserTask")
        
        // Default sort by dueDate, soonest first, then by creationDate, newest first
        let dueDateSort = NSSortDescriptor(key: "dueDate", ascending: true)
        let creationDateSort = NSSortDescriptor(key: "creationDate", ascending: false)
        fetchRequest.sortDescriptors = [dueDateSort, creationDateSort]
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching tasks: \(error)")
            return []
        }
    }
    
    func saveTask(description: String, dueDate: Date? = nil) -> UserTask? {
        let context = persistentContainer.viewContext
        
        if let task = NSEntityDescription.insertNewObject(forEntityName: "UserTask", into: context) as? UserTask {
            task.id = UUID()
            task.taskDescription = description
            task.dueDate = dueDate
            task.creationDate = Date()
            task.isCompleted = false
            
            saveContext()
            return task
        }
        return nil
    }
    
    func saveReminder(title: String, date: Date, notes: String? = nil) -> UserTask? {
        let context = persistentContainer.viewContext
        
        if let reminder = NSEntityDescription.insertNewObject(forEntityName: "UserTask", into: context) as? UserTask {
            reminder.id = UUID()
            reminder.taskDescription = title
            reminder.dueDate = date
            reminder.creationDate = Date()
            reminder.isCompleted = false
            
            saveContext()
            return reminder
        }
        return nil
    }
    
    // MARK: - UserPreference Methods with Combine
    func fetchPreference(forKey key: String) -> AnyPublisher<String?, Error> {
        return Future<String?, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "LocalStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<UserPreference>(entityName: "UserPreference")
            fetchRequest.predicate = NSPredicate(format: "key == %@", key)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(fetchRequest)
                promise(.success(results.first?.value))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // Legacy method for backward compatibility
    func fetchPreferenceSync(forKey key: String) -> String? {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<UserPreference>(entityName: "UserPreference")
        fetchRequest.predicate = NSPredicate(format: "key == %@", key)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.first?.value
        } catch {
            print("Error fetching preference for key \(key): \(error)")
            return nil
        }
    }
    
    func savePreference(key: String, value: String) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "LocalStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            let context = self.persistentContainer.viewContext
            
            // First check if this key already exists
            let fetchRequest = NSFetchRequest<UserPreference>(entityName: "UserPreference")
            fetchRequest.predicate = NSPredicate(format: "key == %@", key)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(fetchRequest)
                if let existingPreference = results.first {
                    // Update existing
                    existingPreference.value = value
                } else {
                    // Create new
                    if let preference = NSEntityDescription.insertNewObject(forEntityName: "UserPreference", into: context) as? UserPreference {
                        preference.id = UUID()
                        preference.key = key
                        preference.value = value
                    }
                }
                self.saveContext()
                promise(.success(true))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - AgentConfiguration Methods with Combine
    func fetchAgentConfigurations() -> AnyPublisher<[AgentConfiguration], Error> {
        return Future<[AgentConfiguration], Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "LocalStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            let context = self.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<AgentConfiguration>(entityName: "AgentConfiguration")
            
            do {
                let configurations = try context.fetch(fetchRequest)
                promise(.success(configurations))
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
    
    // Legacy method for backward compatibility
    func fetchAgentConfigurationsSync() -> [AgentConfiguration] {
        let context = persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<AgentConfiguration>(entityName: "AgentConfiguration")
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Error fetching agent configurations: \(error)")
            return []
        }
    }
    
    func saveAgentConfiguration(agentId: String, name: String, settings: String? = nil, isEnabled: Bool = true) -> AnyPublisher<AgentConfiguration?, Error> {
        return Future<AgentConfiguration?, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "LocalStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"])))
                return
            }
            
            let context = self.persistentContainer.viewContext
            
            // Check if this agent already exists
            let fetchRequest = NSFetchRequest<AgentConfiguration>(entityName: "AgentConfiguration")
            fetchRequest.predicate = NSPredicate(format: "agentId == %@", agentId)
            fetchRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(fetchRequest)
                if let existingConfig = results.first {
                    // Update existing
                    existingConfig.name = name
                    existingConfig.settings = settings
                    existingConfig.isEnabled = isEnabled
                    self.saveContext()
                    promise(.success(existingConfig))
                } else {
                    // Create new
                    if let config = NSEntityDescription.insertNewObject(forEntityName: "AgentConfiguration", into: context) as? AgentConfiguration {
                        config.id = UUID()
                        config.agentId = agentId
                        config.name = name
                        config.settings = settings
                        config.isEnabled = isEnabled
                        self.saveContext()
                        promise(.success(config))
                    } else {
                        promise(.success(nil))
                    }
                }
            } catch {
                promise(.failure(error))
            }
        }.eraseToAnyPublisher()
    }
} 