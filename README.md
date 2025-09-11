# SSM (Swift State Management)

A Swift package for predictable state management using the reducer pattern, designed for SwiftUI applications with support for async operations and dependency injection.

## Installation

### Swift Package Manager

Add SSM to your project using Xcode:

1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/your-username/SSM`
3. Choose the version and add to your target

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/SSM", from: "1.0.0")
]
```

### Platform Requirements

- iOS 17.0+
- macOS 14.0+
- tvOS 17.0+
- watchOS 9.0+
- visionOS 1.0+

## Core Concepts

SSM provides two main libraries:
- **SSM**: Core state management with stores and reducers
- **LoadableValues**: Async state management utilities

## How to Create a Reducer

A reducer defines how state changes in response to requests. Here's the basic structure:

```swift
import SSM

struct UserProfileReducer: Reducer {
    // 1. Define your state
    struct State {
        var profile: LoadableValue<UserProfile, Error> = .idle
        var isEditing: Bool = false
    }
    
    // 2. Define your requests (actions)
    enum Request {
        case loadProfile
        case toggleEditing
        case updateProfile(UserProfile)
    }
    
    // 3. Define your environment (dependencies)
    struct Environment {
        let userService: UserService
        let logger: Logger
    }
    
    // 4. Implement the reduce function
    func reduce(store: Store<Self>, request: Request) async {
        switch request {
        case .loadProfile:
            await load(store: store, keyPath: \.profile) { env in
                try await env.userService.fetchProfile()
            }
            
        case .toggleEditing:
            modifyValue(store: store, \.isEditing) { $0.toggle() }
            
        case .updateProfile(let profile):
            await perform(store: store, keyPath: \.profile) { env in
                try await env.userService.updateProfile(profile)
                return .loaded(LoadingSuccess(value: profile, timestamp: Date()))
            }
        }
    }
    
    // 5. Optional: Set up subscriptions to external events
    func setupSubscriptions(store: Store<Self>) {
        subscribe(store: store, keypath: \.userService) { service in
            service.profileUpdatedPublisher
        } map: { _ in
            .loadProfile
        }
    }
}
```

## How to Create a Store

A store manages state and executes requests through its reducer:

### Basic Store Creation

```swift
// Create environment with dependencies
let environment = UserProfileReducer.Environment(
    userService: UserService(),
    logger: Logger()
)

// Create store with initial state
let store = Store<UserProfileReducer>(
    initialState: UserProfileReducer.State(),
    environment: environment
)

// Send requests to update state
await store.send(.loadProfile)
store.send(.toggleEditing) // Non-async version
```

### Store with Identifiable State

If your state conforms to `Identifiable`, you can use the convenience initializer:

```swift
struct IdentifiableState: Identifiable {
    let id = UUID()
    var name: String = ""
}

struct MyReducer: Reducer {
    typealias State = IdentifiableState
    // ... rest of reducer
}

let store = Store(
    initialState: IdentifiableState(),
    environment: environment
)
```

## How to Use the StoreContainer

`StoreContainer` manages multiple store instances, providing caching and dependency injection:

```swift
// 1. Create a root environment
struct AppEnvironment: Sendable {
    let userService: UserService
    let networkClient: NetworkClient
    let logger: Logger
}

let appEnvironment = AppEnvironment(
    userService: UserService(),
    networkClient: NetworkClient(),
    logger: Logger()
)

// 2. Create store container
let container = StoreContainer(environment: appEnvironment)

// 3. Get stores with scoped environments
let userStore = container.store(
    state: UserProfileReducer.State()
) { appEnv in
    UserProfileReducer.Environment(
        userService: appEnv.userService,
        logger: appEnv.logger
    )
}

// 4. Get singleton stores by type
let settingsStore = container.store(
    type: SettingsReducer.self,
    state: SettingsReducer.State()
) { appEnv in
    SettingsReducer.Environment(logger: appEnv.logger)
}

// 5. For reducers with Void environment
let simpleStore = container.store(
    type: CounterReducer.self,
    state: CounterReducer.State()
)
```

## Helper Functions in the Reducer Protocol

SSM provides several helper functions to simplify common operations:

### Async Operations

```swift
// Load data with automatic loading state management
await load(store: store, keyPath: \.data) { env in
    try await env.apiClient.fetchData()
}

// Load with data transformation
await load(store: store, keyPath: \.summary, work: { env in
    try await env.apiClient.fetchFullData()
}, map: { fullData in
    DataSummary(from: fullData)
})

// Perform async work without loading states
await perform(store: store, keyPath: \.timestamp) { env in
    Date()
}
```

### State Modifications

```swift
// Modify values in place
modifyValue(store: store, \.settings) { settings in
    settings.darkMode.toggle()
}

// Modify loaded values safely
modifyLoadedValue(store: store, \.userProfile) { profile in
    profile.lastLoginDate = Date()
}
```

### Environment Access

```swift
// Access specific dependencies
let isOnline = withEnvironment(store: store, keyPath: \.networkMonitor) { monitor in
    monitor.isConnected
}

// Async environment access
let user = await withEnvironment(store: store, keyPath: \.userService) { service in
    try await service.getCurrentUser()
}
```

### Broadcasting

```swift
// Send messages to other parts of the app
broadcast(UserDidSignOutMessage())
```

### Subscriptions

```swift
// Subscribe to Combine publishers
subscribe(store: store, keypath: \.notificationService) { service in
    service.notificationPublisher
} map: { notification in
    .handleNotification(notification)
}

// Subscribe to AsyncStreams
subscribe(store: store, keypath: \.timerService) { service in
    service.tickStream()
} map: { _ in
    .timerTick
}
```

## Testing

SSM includes built-in testing support with a special `TestContext` that allows you to mock async operations:

### Basic Testing

```swift
import Testing
@testable import SSM

@Test
func testUserProfileLoading() async {
    let mockService = MockUserService()
    let environment = UserProfileReducer.Environment(
        userService: mockService,
        logger: Logger()
    )
    
    let store = Store<UserProfileReducer>(
        initialState: UserProfileReducer.State(),
        environment: environment
    )
    
    await store.send(.loadProfile)
    
    // Assert state changes
    #expect(store.profile.value != nil)
}
```

### Using TestContext for Async Operations

When testing reducers that use helper functions like `load()`, `perform()`, etc., SSM automatically provides a `TestContext` that allows you to simulate async results:

```swift
@Test
func testRecipeLoading() async throws {
    let store = Store<RecipeReducer>(
        initialState: RecipeReducer.State(),
        environment: ()
    )
    
    // Send the request that would normally trigger async loading
    await store.send(.fetchRecipes)
    
    // Use testContext to provide the async result
    store.testContext?.makeValueForAwaitingKeypath(
        for: \.recipes,
        .loaded(LoadingSuccess(value: [.burger, .pizza], timestamp: .now))
    ) { state in
        // Assert the state after the value is set
        #expect(state.recipes.value?.count == 2)
        #expect(state.recipes.value?.contains(.burger) == true)
    }
}
```

### TestContext Methods

The `TestContext` provides several methods for testing:

#### `makeValueForAwaitingKeypath`
Provides a value for a keypath that's waiting for an async operation to complete:

```swift
store.testContext?.makeValueForAwaitingKeypath(
    for: \.someLoadableValue,
    .loaded(LoadingSuccess(value: expectedValue, timestamp: .now))
) { state in
    // Assertions here
    #expect(state.someLoadableValue.value == expectedValue)
}
```

#### `forget`
Removes a keypath from the test queue if you don't want to provide a value:

```swift
store.testContext?.forget(keypath: \.someValue)
```

### Testing Patterns

#### Testing Loading States

```swift
@Test
func testLoadingStates() async {
    let store = Store<DataReducer>(
        initialState: DataReducer.State(),
        environment: DataReducer.Environment()
    )
    
    // Initial state should be idle
    #expect(store.data == .idle)
    
    // Send loading request
    await store.send(.loadData)
    
    // Simulate successful loading
    store.testContext?.makeValueForAwaitingKeypath(
        for: \.data,
        .loaded(LoadingSuccess(value: mockData, timestamp: .now))
    ) { state in
        #expect(state.data.value == mockData)
    }
}
```

#### Testing Error States

```swift
@Test
func testErrorHandling() async {
    let store = Store<DataReducer>(
        initialState: DataReducer.State(),
        environment: DataReducer.Environment()
    )
    
    await store.send(.loadData)
    
    // Simulate failure
    store.testContext?.makeValueForAwaitingKeypath(
        for: \.data,
        .failed(LoadingFailure(failure: NetworkError.connectionLost, timestamp: .now))
    ) { state in
        #expect(state.data.isFailure == true)
        #expect(state.data.failure as? NetworkError == .connectionLost)
    }
}
```

### Important Testing Notes

- The `TestContext` is only available in `DEBUG` builds 
- When using helper functions like `load()` or `perform()` in tests, they automatically register with the `TestContext` instead of performing real async work
- You must provide values for all registered keypaths using `makeValueForAwaitingKeypath` or `forget` them
- The test context will report issues if you don't handle all awaiting keypaths before deinitialization

## Boxed State

`BoxedState` provides a way to observe specific parts of your store's state:

```swift
// Create a boxed state that observes a specific value
let userNameBox = BoxedState(
    of: \.profile,
    in: store,
    map: { profile in
        profile.value?.name ?? "Unknown"
    }
)

// Access the observed value
let userName = userNameBox.value

// Use with SwiftUI
struct UserView: View {
    let userNameBox: BoxedState<UserReducer, LoadableValue<User, Error>, String>
    
    var body: some View {
        Text(userNameBox.value)
    }
}
```

For values that don't need transformation:

```swift
let profileBox = BoxedState(of: \.profile, in: store)
```

## Loadable Values

`LoadableValue` represents the state of async operations:

```swift
// States
var data: LoadableValue<[Item], Error> = .idle     // Not started
var data: LoadableValue<[Item], Error> = .loading  // In progress
var data: LoadableValue<[Item], Error> = .loaded(success) // Completed successfully
var data: LoadableValue<[Item], Error> = .failed(error)   // Failed with error
var data: LoadableValue<[Item], Error> = .cancelled(date) // Cancelled

// Common usage patterns
switch data {
case .idle:
    Text("Tap to load")
case .loading:
    ProgressView()
case .loaded(let success):
    List(success.value, id: \.id) { item in
        Text(item.name)
    }
case .failed(let failure):
    Text("Error: \(failure.failure.localizedDescription)")
case .cancelled:
    Text("Cancelled")
}

// Convenience properties
if let value = data.value {
    // Use loaded value
}

if data.isLoading() {
    // Show loading indicator
}

if let error = data.failure {
    // Handle error
}
```

### Modifying Loaded Values

```swift
// Safely modify loaded values
data.modify { items in
    items.append(newItem)
}
```

## SwiftUI Integration

SSM integrates seamlessly with SwiftUI through the `@Observable` macro and provides several SwiftUI-specific utilities:

### Basic Store Observation

```swift
struct ContentView: View {
    let store: Store<UserProfileReducer>
    
    var body: some View {
        VStack {
            switch store.profile {
            case .idle:
                Button("Load Profile") {
                    store.send(.loadProfile)
                }
            case .loading:
                ProgressView("Loading...")
            case .loaded(let success):
                ProfileView(profile: success.value)
            case .failed(let failure):
                ErrorView(error: failure.failure)
            case .cancelled:
                Text("Cancelled")
            }
        }
    }
}
```

### SwiftUI Bindings

Create two-way bindings to store state:

```swift
struct SettingsView: View {
    let store: Store<SettingsReducer>
    
    var body: some View {
        Form {
            Toggle("Dark Mode", isOn: store.binding(\.isDarkMode, default: false))
            TextField("Username", text: store.binding(\.username, default: ""))
        }
    }
}

// Alternative syntax
struct AlternativeView: View {
    let store: Store<SettingsReducer>
    
    var body: some View {
        @State var darkMode = Binding(from: store, \.isDarkMode, default: false)
        
        Toggle("Dark Mode", isOn: darkMode)
    }
}
```

### LoadableValue SwiftUI Modifiers

React to different LoadableValue states declaratively:

```swift
struct DataView: View {
    let store: Store<DataReducer>
    
    var body: some View {
        VStack {
            if let data = store.data.value {
                List(data, id: \.id) { item in
                    Text(item.name)
                }
            }
        }
        .onIdle(of: store.data) {
            store.send(.loadData)
        }
        .onLoading(of: store.data) {
            // Handle loading state
        }
        .onLoadingComplete(of: store.data) { success in
            // Handle successful load
            print("Data loaded at \(success.timestamp)")
        }
        .onFailure(of: store.data) { failure in
            // Handle failure
            showErrorAlert(failure.failure)
        }
        .onCancellation(of: store.data) { date in
            // Handle cancellation
            print("Operation cancelled at \(date)")
        }
    }
}
```

## Broadcasting System

SSM includes a global broadcasting system for decoupled communication between different parts of your app:

### Creating Broadcast Messages

```swift
struct UserDidSignOutMessage: BroadcastMessage {
    let id = UUID()
    let name = "User Did Sign Out"
    let originatingFrom: any StoreProtocol
    let userId: String
}

struct DataUpdatedMessage: BroadcastMessage {
    let id = UUID()
    let name = "Data Updated"
    let originatingFrom: any StoreProtocol
    let dataType: String
}
```

### Broadcasting Messages

```swift
// From within a reducer
func reduce(store: Store<Self>, request: Request) async {
    switch request {
    case .signOut:
        // Perform sign out logic
        await signOut()
        
        // Broadcast the event
        broadcast(UserDidSignOutMessage(
            originatingFrom: store,
            userId: store.currentUserId
        ))
    }
}
```

### Listening to Broadcasts

```swift
func setupSubscriptions(store: Store<Self>) {
    subscribe(store: store, keypath: \.broadcastStudio) { studio in
        studio.publisher
    } map: { message in
        switch message {
        case let userSignOut as UserDidSignOutMessage:
            return .handleUserSignOut(userSignOut.userId)
        case let dataUpdate as DataUpdatedMessage:
            return .refreshData(dataUpdate.dataType)
        default:
            return nil
        }
    }
}
```

## Best Practices

1. **Keep reducers pure**: All side effects should go through the environment
2. **Use LoadableValue for async operations**: It provides built-in loading state management
3. **Leverage the helper functions**: They handle common patterns and edge cases
4. **Structure your environment**: Group related dependencies together
5. **Test with mock environments**: Create test versions of your dependencies
6. **Use StoreContainer for complex apps**: It helps manage multiple stores and their dependencies

## Examples

Check the `Tests/SSMTests/Samples/` directory for complete examples including:
- `FootballerReducer`: Demonstrates async loading and broadcasting
- `RecipeReducer`: Shows basic state management patterns
- `NavigationReducer`: Example of navigation state handling

## License

[Add your license information here]
