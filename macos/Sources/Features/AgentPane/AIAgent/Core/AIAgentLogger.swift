import Foundation
import os.log

/// Logger for AI Agent operations
enum AIAgentLogger {
    private static let subsystem = "com.mitchellh.ghostty.agent"
    
    static let general = Logger(subsystem: subsystem, category: "general")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let tools = Logger(subsystem: subsystem, category: "tools")
    static let streaming = Logger(subsystem: subsystem, category: "streaming")
    
    /// Log levels for different verbosity
    enum Level {
        case debug, info, warning, error
    }
    
    /// Log a message with the appropriate level
    static func log(_ level: Level, category: Logger, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let context = "[\(fileName):\(line)]"
        
        switch level {
        case .debug:
            category.debug("\(context) \(message)")
        case .info:
            category.info("\(context) \(message)")
        case .warning:
            category.warning("\(context) \(message)")
        case .error:
            category.error("\(context) \(message)")
        }
    }
}

/// Convenience extensions for logging
extension AIAgentLogger {
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: general, message, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: general, message, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: general, message, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, category: general, message, file: file, function: function, line: line)
    }
}

/// Timeout helper for async operations
enum AsyncTimeout {
    /// Run an async operation with a timeout
    static func run<T>(
        timeout: Duration,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(for: timeout)
                throw AIModelError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
