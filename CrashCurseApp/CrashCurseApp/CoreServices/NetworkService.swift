import Foundation
import Combine
import CoreData

// MARK: - AnyCodable for dynamic JSON handling
struct AnyCodable: Codable {
    let value: Any
    
    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            value = ()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let anyArray = array.map { AnyCodable($0) }
            try container.encode(anyArray)
        case let dictionary as [String: Any]:
            let anyDictionary = dictionary.mapValues { AnyCodable($0) }
            try container.encode(anyDictionary)
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

// Response models
struct ChatResponse: Codable {
    let message: String
    let timestamp: String
    
    // Action fields
    let action: String?
    
    // Navigation
    let navigation: Bool?
    let destination: String?
    let transport_mode: String?
    let apple_maps_url: String?
    let maps_scheme_url: String?
    
    // Weather
    let weather: Bool?
    let location: String?
    let temperature: String?
    let description: String?
    let humidity: String?
    let feels_like: String?
    let wind_speed: String?
    let is_real_data: Bool?
    
    // Calendar
    let calendar: Bool?
    let event_title: String?
    let event_date: String?
    let event_time: String?
    let event_location: String?
    
    // Reminders
    let reminder: Bool?
    let reminder_text: String?
    let reminder_time: String?
    
    // OpenAPI fields
    let api_response: [String: AnyCodable]?
    let api_status: String?
    let agent_used: String?
    
    // Convenience properties
    var isNavigationRequest: Bool {
        return navigation == true && destination != nil
    }
    
    var isWeatherRequest: Bool {
        return weather == true
    }
    
    var isAPIRequest: Bool {
        return api_response != nil || api_status != nil
    }
    
    var navigationURL: URL? {
        if let urlString = maps_scheme_url ?? apple_maps_url {
            return URL(string: urlString)
        }
        return nil
    }
}

struct EventResponse: Decodable {
    let success: Bool
    let message: String
    let event_id: String?
}

struct ReminderResponse: Decodable {
    let success: Bool
    let message: String
    let reminder_id: String?
}

// MARK: - Network Error Types
enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
    case apiCallFailed(Int)
    case noDataReceived
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .decodingError:
            return "Failed to decode response"
        case .apiCallFailed(let code):
            return "API call failed with status code: \(code)"
        case .noDataReceived:
            return "No data received"
        }
    }
}

class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    // Single unified backend URL
    private let backendURL = "https://mobile.labai.ws"  // Changed from port 8080 to standard HTTPS (443)
    
    private let openAPIManager = OpenAPIManager.shared
    private let session = URLSession.shared
    
    private let apiKey = "supersecretapikey" // Use the same key as in the backend or from secure storage
    
    // MARK: - Chat Endpoints
    func sendMessage(_ message: String, userId: String = "ios_user") -> AnyPublisher<ChatResponse, Error> {
        guard let url = URL(string: "\(backendURL)/api/v1/chat/send") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        
        let requestBody = [
            "message": message,
            "user_id": userId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ChatResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func getChatHistory(userId: String = "ios_user") -> AnyPublisher<[ChatResponse], Error> {
        guard let url = URL(string: "\(backendURL)/api/v1/chat/history/\(userId)") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [ChatResponse].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Planning Endpoints
    func createEvent(title: String, startDate: Date, endDate: Date?, location: String? = nil, notes: String? = nil) -> AnyPublisher<EventResponse, Error> {
        guard let url = URL(string: "\(backendURL)/api/v1/planning/events") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        
        let dateFormatter = ISO8601DateFormatter()
        let requestBody: [String: Any] = [
            "title": title,
            "start_date": dateFormatter.string(from: startDate),
            "end_date": endDate != nil ? dateFormatter.string(from: endDate!) : NSNull(),
            "location": location ?? NSNull(),
            "notes": notes ?? NSNull()
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: EventResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func createReminder(title: String, dueDate: Date?, notes: String? = nil) -> AnyPublisher<ReminderResponse, Error> {
        guard let url = URL(string: "\(backendURL)/api/v1/planning/reminders") else {
            return Fail(error: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        
        let dateFormatter = ISO8601DateFormatter()
        let requestBody: [String: Any] = [
            "title": title,
            "due_date": dueDate != nil ? dateFormatter.string(from: dueDate!) : NSNull(),
            "notes": notes ?? NSNull()
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ReminderResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Health Check
    func healthCheck() -> AnyPublisher<Bool, Error> {
        guard let url = URL(string: "\(backendURL)/health") else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        
        return session.dataTaskPublisher(for: request)
            .map { data, response in
                if let httpResponse = response as? HTTPURLResponse {
                    return httpResponse.statusCode == 200
                }
                return false
            }
            .catch { _ in 
                Just(false).setFailureType(to: Error.self)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Backend Status Check (Unified)
    func checkBackendStatus() -> AnyPublisher<[String: Bool], Error> {
        return healthCheck()
            .map { isHealthy in
                return ["unified_backend": isHealthy]
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - OpenAPI Integration
    func callOpenAPI(
        url: String,
        method: String = "GET",
        headers: [String: String]? = nil,
        data: [String: Any]? = nil,
        params: [String: String]? = nil
    ) async throws -> OpenAPIResponse {
        
        let httpMethod: OpenAPIRequest.HTTPMethod
        switch method.uppercased() {
        case "GET": httpMethod = .GET
        case "POST": httpMethod = .POST
        case "PUT": httpMethod = .PUT
        case "DELETE": httpMethod = .DELETE
        case "PATCH": httpMethod = .PATCH
        default: httpMethod = .GET
        }
        
        return try await openAPIManager.callCustomAPI(
            url: url,
            method: httpMethod,
            headers: headers,
            jsonBody: data,
            parameters: params
        )
    }
    
    func getWeatherViaOpenAPI(city: String) async throws -> WeatherData {
        // Use environment variable or default demo mode
        let apiKey = ProcessInfo.processInfo.environment["OPENWEATHER_API_KEY"] ?? ""
        
        if apiKey.isEmpty {
            // Return demo data
            throw OpenAPIError.apiCallFailed(401)
        }
        
        return try await openAPIManager.getWeather(for: city, apiKey: apiKey)
    }
    
    func getNewsViaOpenAPI(query: String) async throws -> NewsResponse {
        let apiKey = ProcessInfo.processInfo.environment["NEWS_API_KEY"] ?? ""
        
        if apiKey.isEmpty {
            throw OpenAPIError.apiCallFailed(401)
        }
        
        return try await openAPIManager.getNews(query: query, apiKey: apiKey)
    }
    
    func getExchangeRatesViaOpenAPI() async throws -> ExchangeRateResponse {
        return try await openAPIManager.getExchangeRates()
    }
    
    // MARK: - Backend API Call with OpenAPI support
    func sendMessageWithOpenAPI(_ message: String, userId: String = "ios_user", agentType: String = "auto") async throws -> ChatResponse {
        let url = URL(string: "\(backendURL)/api/v1/chat/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "X-API-KEY")
        
        let requestBody = [
            "message": message,
            "user_id": userId,
            "agent_type": agentType
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }
} 
