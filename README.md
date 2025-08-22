# SSM (State Store Manager) 🏪

[![Swift](https://img.shields.io/badge/Swift-6.1+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017%2B%20|%20macOS%2014%2B%20|%20tvOS%2017%2B%20|%20watchOS%209%2B%20|%20visionOS%201%2B-blue.svg)](https://developer.apple.com/swift)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A powerful, type-safe, and observable state management framework for Swift applications. SSM provides a Redux-inspired architecture with modern Swift concurrency support, making it perfect for SwiftUI apps and complex state management scenarios.

## ✨ Features

- **🔒 Type-Safe**: Fully type-safe state management with Swift's type system
- **🎯 Observable**: Built-in SwiftUI integration with `@Observable` support
- **⚡ Async/Await**: Native Swift concurrency with structured async/await patterns
- **🔄 LoadableValues**: Built-in loading state management for async operations
- **📡 Broadcasting**: Decoupled communication system for cross-cutting concerns  
- **🧪 Testable**: Designed with testing in mind - easy to mock and test
- **🎛️ Composable**: Support for composed stores and modular architecture
- **🏗️ Reducer Pattern**: Predictable state updates through the reducer pattern
- **🚀 Performance**: Efficient state updates with minimal overhead

## 🚀 Quick Start

### Installation

Add SSM to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SSM.git", from: "1.0.0")
]
```

### Basic Usage

#### 1. Define your Reducer

```swift
import SSM
import LoadableValues

struct UserProfileReducer: Reducer {
    struct State {
        var profile: LoadableValue<UserProfile, Error> = .idle
        var isEditing: Bool = false
    }
    
    enum Request {
        case loadProfile
        case toggleEditing
        case updateProfile(UserProfile)
    }
    
    struct Environment {
        let userService: UserService
        let analytics: AnalyticsService
    }
    
    func reduce(store: Store<Self>, request: Request) async {
        switch request {
        case .loadProfile:
            await load(store: store, keyPath: \.profile) { env in
                try await env.userService.fetchProfile()
            }
            
        case .toggleEditing:
            modifyValue(store: store, \.isEditing) { $0.toggle() }
            
        case .updateProfile(let profile):
            await load(store: store, keyPath: \.profile) { env in
                try await env.userService.update(profile)
            }
        }
    }
}
```

#### 2. Create and Use your Store

```swift
let store = Store<UserProfileReducer>(
    initialState: UserProfileReducer.State(),
    environment: UserProfileReducer.Environment(
        userService: UserService(),
        analytics: AnalyticsService()
    )
)

// Load user profile
await store.send(.loadProfile)

// Access state with dynamic member lookup
let isLoading = store.profile.isLoading()
let userName = store.profile.value?.name
```

#### 3. SwiftUI Integration

```swift
struct UserProfileView: View {
    let store: Store<UserProfileReducer>
    
    var body: some View {
        VStack {
            switch store.profile {
            case .idle:
                Text("Tap to load profile")
            case .loading:
                ProgressView("Loading...")
            case .loaded(let success):
                UserProfileCard(profile: success.value)
            case .failed(let failure):
                ErrorView(error: failure.failure)
            case .cancelled:
                Text("Loading cancelled")
            }
        }
        .onAppear {
            store.send(.loadProfile)
        }
    }
}
```

## 📚 Core Concepts

### LoadableValue

`LoadableValue` is a powerful enum that represents the state of async operations:

```swift
enum LoadableValue<Value, Failure: Error> {
    case idle           // Initial state
    case loading        // Operation in progress  
    case loaded(value)  // Success with value and timestamp
    case failed(error)  // Failed with error and timestamp
    case cancelled(date)// Operation was cancelled
}
```

### Broadcasting System

Communicate across different parts of your app with the broadcasting system:

```swift
// Define a broadcast message
struct UserDidLogOut: BroadcastMessage {}

// Send from any reducer
broadcast(UserDidLogOut())

// Listen in any reducer
func didReceiveBroadcastMessage(_ message: any BroadcastMessage, in store: Store<Self>) async {
    if message is UserDidLogOut {
        // Handle user logout
        modifyValue(store: store, \.isLoggedIn) { $0 = false }
    }
}
```

### Composed Stores

Build complex features by composing multiple stores:

```swift
struct AppReducer: ComposedStoreReducer {
    struct State {
        var user = Store<UserReducer>.State()
        var settings = Store<SettingsReducer>.State()
    }
    
    enum Request {
        case user(UserReducer.Request)
        case settings(SettingsReducer.Request)
    }
}
```

## 🔧 Advanced Features

### Task Management

SSM automatically manages async tasks and provides cancellation support:

```swift
// Cancel specific loading operations
store.cancelActiveTask(for: \.profile)

// Tasks are automatically cancelled when stores are deallocated
```

### Environment Dependencies

Inject dependencies cleanly through the environment:

```swift
struct Environment {
    let apiClient: APIClient
    let database: Database
    let logger: Logger
}

// Use in reducers
func reduce(store: Store<Self>, request: Request) async {
    withEnvironment(store: store, keyPath: \.logger) { logger in
        logger.info("Processing request: \(request)")
    }
}
```

### Debug Support

Built-in debugging capabilities for development:

```swift
#if DEBUG
// Access state change history
print(store.valueChanges)
#endif
```

## 🧪 Testing

SSM is designed with testing in mind:

```swift
func testUserProfileLoading() async {
    let mockService = MockUserService()
    let store = Store<UserProfileReducer>(
        initialState: .init(),
        environment: .init(userService: mockService)
    )
    
    await store.send(.loadProfile)
    
    XCTAssertTrue(store.profile.isLoading())
    
    // Wait for async completion
    await Task.yield()
    
    XCTAssertNotNil(store.profile.value)
}
```

## 📖 Documentation

For detailed documentation, examples, and best practices, visit our [documentation site](https://yourusername.github.io/SSM/).

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

SSM is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## 🙏 Acknowledgments

- Inspired by Redux and The Composable Architecture (TCA)
- Built with modern Swift concurrency in mind
- Designed for the SwiftUI era

---

<div align="center">
  <strong>Built with ❤️ for the Swift community</strong>
</div>