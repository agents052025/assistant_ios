import Foundation
import Network

// MARK: - OpenAPI Models
struct OpenAPIRequest {
    let url: String
    let method: HTTPMethod
    let headers: [String: String]?
    let body: Data?
    let parameters: [String: String]?
    
    enum HTTPMethod: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case DELETE = "DELETE"
        case PATCH = "PATCH"
    }
}

struct OpenAPIResponse {
    let statusCode: Int
    let data: Data?
    let headers: [String: String]
    let success: Bool
    
    var jsonObject: Any? {
        guard let data = data else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
    
    var dictionary: [String: Any]? {
        return jsonObject as? [String: Any]
    }
    
    var array: [Any]? {
        return jsonObject as? [Any]
    }
}

// MARK: - OpenAPI Manager
class OpenAPIManager: ObservableObject {
    static let shared = OpenAPIManager()
    
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "OpenAPIManager")
    
    @Published var isConnected = true
    @Published var lastAPICall: Date?
    @Published var apiCallCount = 0
    
    // Common API endpoints
    struct Endpoints {
        static let weather = "https://api.openweathermap.org/data/2.5/weather"
        static let news = "https://newsapi.org/v2/everything"
        static let exchangeRates = "https://api.exchangerate-api.com/v4/latest/USD"
        static let geoLocation = "https://api.opencagedata.com/geocode/v1/json"
    }
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
        
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    // MARK: - Generic API Call
    func callAPI(_ request: OpenAPIRequest) async throws -> OpenAPIResponse {
        guard isConnected else {
            throw OpenAPIError.networkUnavailable
        }
        
        let urlRequest = try buildURLRequest(from: request)
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAPIError.invalidResponse
            }
            
            updateCallStatistics()
            
            let apiResponse = OpenAPIResponse(
                statusCode: httpResponse.statusCode,
                data: data,
                headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
                success: (200...299).contains(httpResponse.statusCode)
            )
            
            return apiResponse
            
        } catch {
            throw OpenAPIError.requestFailed(error.localizedDescription)
        }
    }
    
    private func buildURLRequest(from request: OpenAPIRequest) throws -> URLRequest {
        var components = URLComponents(string: request.url)
        
        // Add query parameters
        if let parameters = request.parameters {
            components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = components?.url else {
            throw OpenAPIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        
        // Add headers
        if let headers = request.headers {
            for (key, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Add body
        urlRequest.httpBody = request.body
        
        return urlRequest
    }
    
    private func updateCallStatistics() {
        DispatchQueue.main.async {
            self.lastAPICall = Date()
            self.apiCallCount += 1
        }
    }
    
    // MARK: - Weather API
    func getWeather(for city: String, apiKey: String) async throws -> WeatherData {
        let request = OpenAPIRequest(
            url: Endpoints.weather,
            method: .GET,
            headers: ["Content-Type": "application/json"],
            body: nil,
            parameters: [
                "q": city,
                "appid": apiKey,
                "units": "metric",
                "lang": "uk"
            ]
        )
        
        let response = try await callAPI(request)
        
        guard response.success, let data = response.data else {
            throw OpenAPIError.apiCallFailed(response.statusCode)
        }
        
        return try JSONDecoder().decode(WeatherData.self, from: data)
    }
    
    // MARK: - News API
    func getNews(query: String, apiKey: String, language: String = "uk") async throws -> NewsResponse {
        let request = OpenAPIRequest(
            url: Endpoints.news,
            method: .GET,
            headers: ["Content-Type": "application/json"],
            body: nil,
            parameters: [
                "q": query,
                "apiKey": apiKey,
                "language": language,
                "sortBy": "publishedAt",
                "pageSize": "5"
            ]
        )
        
        let response = try await callAPI(request)
        
        guard response.success, let data = response.data else {
            throw OpenAPIError.apiCallFailed(response.statusCode)
        }
        
        return try JSONDecoder().decode(NewsResponse.self, from: data)
    }
    
    // MARK: - Exchange Rates API
    func getExchangeRates(baseCurrency: String = "USD") async throws -> ExchangeRateResponse {
        let url = "https://api.exchangerate-api.com/v4/latest/\(baseCurrency)"
        
        let request = OpenAPIRequest(
            url: url,
            method: .GET,
            headers: ["Content-Type": "application/json"],
            body: nil,
            parameters: nil
        )
        
        let response = try await callAPI(request)
        
        guard response.success, let data = response.data else {
            throw OpenAPIError.apiCallFailed(response.statusCode)
        }
        
        return try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
    }
    
    // MARK: - Custom API Call
    func callCustomAPI(
        url: String,
        method: OpenAPIRequest.HTTPMethod = .GET,
        headers: [String: String]? = nil,
        jsonBody: [String: Any]? = nil,
        parameters: [String: String]? = nil
    ) async throws -> OpenAPIResponse {
        
        var body: Data?
        if let jsonBody = jsonBody {
            body = try JSONSerialization.data(withJSONObject: jsonBody)
        }
        
        let request = OpenAPIRequest(
            url: url,
            method: method,
            headers: headers,
            body: body,
            parameters: parameters
        )
        
        return try await callAPI(request)
    }
}

// MARK: - API Response Models
struct WeatherData: Codable {
    let name: String
    let main: MainWeather
    let weather: [Weather]
    let wind: Wind
    
    struct MainWeather: Codable {
        let temp: Double
        let feelsLike: Double
        let humidity: Int
        
        enum CodingKeys: String, CodingKey {
            case temp, humidity
            case feelsLike = "feels_like"
        }
    }
    
    struct Weather: Codable {
        let main: String
        let description: String
    }
    
    struct Wind: Codable {
        let speed: Double
    }
}

struct NewsResponse: Codable {
    let status: String
    let totalResults: Int
    let articles: [Article]
    
    struct Article: Codable {
        let title: String
        let description: String?
        let url: String
        let publishedAt: String
        let source: Source
        
        struct Source: Codable {
            let name: String
        }
    }
}

struct ExchangeRateResponse: Codable {
    let base: String
    let date: String
    let rates: [String: Double]
}

// MARK: - OpenAPI Errors
enum OpenAPIError: LocalizedError {
    case networkUnavailable
    case invalidURL
    case invalidResponse
    case requestFailed(String)
    case apiCallFailed(Int)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Мережа недоступна"
        case .invalidURL:
            return "Невірний URL"
        case .invalidResponse:
            return "Невірна відповідь від сервера"
        case .requestFailed(let message):
            return "Запит не вдався: \(message)"
        case .apiCallFailed(let statusCode):
            return "API помилка: код \(statusCode)"
        case .decodingError(let message):
            return "Помилка декодування: \(message)"
        }
    }
} 