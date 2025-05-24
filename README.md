# 📱 CrashCurse iOS App

Мобільний AI асистент для iOS з інтеграцією з багатоагентним backend системою. Підтримує чат з AI, створення подій, погодні запити та навігацію.

## ✨ Особливості

- **🤖 AI Chat**: Інтелектуальний чат з підтримкою різних агентів
- **📅 Календар**: Створення подій та нагадувань через природну мову
- **🌤️ Погода**: Актуальна інформація про погоду в містах України
- **🗺️ Навігація**: Допомога з маршрутизацією та транспортом
- **🔒 Безпека**: API Key аутентифікація та HTTPS з'єднання
- **📱 Native iOS**: SwiftUI інтерфейс з підтримкою iOS 15+

## 🏗️ Архітектура

### 📁 Структура проекту
```
CrashCurseApp/
├── CrashCurseApp/                 # 📱 Основний iOS додаток
│   ├── CrashCurseApp/            # 📂 Core файли
│   │   ├── CoreServices/         # 🔧 Сервіси
│   │   │   └── NetworkService.swift  # 🌐 Мережевий шар
│   │   └── Models/               # 📊 Моделі даних
│   ├── Assets.xcassets/          # 🎨 Ресурси
│   └── CrashCurseApp.xcdatamodeld/  # 📊 Core Data
├── CrashCurseApp.xcodeproj/      # 🔧 Xcode проект
├── CrashCurseAppTests/           # 🧪 Unit тести
└── CrashCurseAppUITests/         # 🧪 UI тести
```

### 🌐 Backend інтеграція

**Backend Repository**: [crashcurse-backend](https://github.com/agents052025/crashcurse-backend)
**Production API**: `https://mobile.labai.ws`
**Local Development**: `http://localhost:8000`

### 🔧 NetworkService

Основний клас для взаємодії з backend API:
- API Key аутентифікація автоматично додається до запитів
- Підтримка всіх endpoint'ів (chat, calendar, weather, navigation)
- Error handling та retry логіка
- Async/await підтримка

## 🚀 Встановлення та запуск

### Передумови
- **Xcode 14.0+**
- **iOS 15.0+**
- **macOS 12.0+** (для розробки)

### 1. Клонування репозиторію
```bash
git clone https://github.com/agents052025/assistant_ios.git
cd assistant_ios
```

### 2. Відкриття в Xcode
```bash
open CrashCurseApp.xcodeproj
```

### 3. Налаштування backend URL

У файлі `CrashCurseApp/CoreServices/NetworkService.swift`:
```swift
// Для локальної розробки
private let backendURL = "http://localhost:8000"

// Для production
private let backendURL = "https://mobile.labai.ws"
```

### 4. Налаштування API ключа

У `NetworkService.swift` змініть API ключ:
```swift
private let apiKey = "your_api_key_here"
```

### 5. Запуск backend (локально)

Клонуйте та запустіть backend:
```bash
git clone https://github.com/agents052025/crashcurse-backend.git
cd crashcurse-backend
./run.sh
```

### 6. Збірка та запуск iOS додатку

1. Виберіть target: **CrashCurseApp**
2. Виберіть simulator або пристрій
3. Натисніть **⌘ + R** для запуску

## 🔧 Конфігурація

### Info.plist налаштування

Для локальної розробки (HTTP з'єднання):
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### Мережеві дозволи

Додайте в `Info.plist` для мережевих запитів:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>mobile.labai.ws</key>
        <dict>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.0</string>
            <key>NSThirdPartyExceptionRequiresForwardSecrecy</key>
            <false/>
        </dict>
    </dict>
</dict>
```

## 🌐 API Integration

### Основні endpoint'и

```swift
// Чат з AI
POST /api/v1/chat/send
Headers: X-API-KEY: supersecretapikey
Body: {"message": "Яка погода в Києві?", "user_id": "ios_user"}

// Історія чату
GET /api/v1/chat/history/ios_user
Headers: X-API-KEY: supersecretapikey

// Створення події
POST /api/v1/calendar/events
Headers: X-API-KEY: supersecretapikey
Body: {"title": "Зустріч", "start_date": "2024-01-01T09:00:00Z"}
```

### Приклад використання NetworkService

```swift
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    private let networkService = NetworkService()
    private var cancellables = Set<AnyCancellable>()
    
    func sendMessage(_ text: String) {
        networkService.sendMessage(text)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Error: \\(error)")
                    }
                },
                receiveValue: { response in
                    self.messages.append(ChatMessage(
                        text: response.message,
                        isUser: false
                    ))
                }
            )
            .store(in: &cancellables)
    }
}
```

## 🧪 Тестування

### Unit тести
```bash
# Запуск unit тестів
⌘ + U (в Xcode)
```

### UI тести
```bash
# Запуск UI тестів
⌘ + Ctrl + U (в Xcode)
```

### Backend підключення
```swift
// Тест з'єднання з backend
func testBackendConnection() {
    let expectation = expectation(description: "Backend connection")
    
    networkService.healthCheck()
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { isHealthy in
                XCTAssertTrue(isHealthy)
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
    
    waitForExpectations(timeout: 5.0)
}
```

## 🔧 Розробка

### Архітектурні патерни
- **MVVM**: Model-View-ViewModel архітектура
- **Combine**: Reactive programming для мережевих запитів
- **SwiftUI**: Декларативний UI framework
- **Core Data**: Локальне збереження даних

### Основні компоненти

**NetworkService**: Центральний клас для API комунікації
**ChatViewModel**: ViewModel для чат функціональності  
**EventManager**: Управління календарними подіями
**WeatherService**: Сервіс погодних даних

### Додавання нових функцій

1. Створіть новий endpoint в backend
2. Додайте метод в `NetworkService.swift`
3. Створіть ViewModel для UI логіки
4. Додайте SwiftUI View для інтерфейсу

## 📊 Performance

### Оптимізації
- Асинхронні мережеві запити
- Кешування відповідей API
- Lazy loading для списків
- Memory management з weak references

### Моніторинг
- Використовуйте Instruments для profiling
- Network profiling для API запитів
- Memory leaks detection

## 🐞 Troubleshooting

### Помилки мережі
```
❌ "Could not connect to backend"
✅ Перевірте чи працює backend на localhost:8000
✅ Перевірте API ключ в NetworkService.swift
```

### Build помилки
```
❌ "Missing API key"
✅ Встановіть правильний API ключ
✅ Перевірте backend URL конфігурацію
```

### Simulator проблеми
```
❌ "App transport security policy"
✅ Додайте NSAllowsArbitraryLoads в Info.plist для розробки
```

## 🚀 Deployment

### App Store підготовка
1. Змініть на production URL: `https://mobile.labai.ws`
2. Видаліть `NSAllowsArbitraryLoads` з Info.plist
3. Налаштуйте правильні app icons
4. Додайте privacy policy URLs

### TestFlight
1. Archive проект (⌘ + Shift + R)
2. Upload до App Store Connect
3. Додайте тестерів
4. Розповсюдьте build

## 🤝 Contribution

1. Fork репозиторій
2. Створіть feature branch (`git checkout -b feature/amazing-feature`)
3. Commit зміни (`git commit -m 'Add amazing feature'`)
4. Push до branch (`git push origin feature/amazing-feature`)
5. Створіть Pull Request

## 📄 Ліцензія

MIT License - деталі в файлі LICENSE

## 🔗 Пов'язані репозиторії

- **Backend**: [crashcurse-backend](https://github.com/agents052025/crashcurse-backend)
- **API Documentation**: https://mobile.labai.ws/docs

## 🆘 Підтримка

- **Issues**: GitHub Issues
- **Backend Health**: https://mobile.labai.ws/health
- **API Docs**: https://mobile.labai.ws/docs

---

**📱 Розроблено з ❤️ на Swift і SwiftUI** 