import Logging

// Suppress log output during tests.
let _ = {
    LoggingSystem.bootstrap(SwiftLogNoOpLogHandler.init)
}()
