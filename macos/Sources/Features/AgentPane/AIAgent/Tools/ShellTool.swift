import Foundation

/// Tool for running shell commands directly (not through the terminal UI)
struct ShellTool: AITool {
    let workingDirectory: String
    let timeout: TimeInterval
    
    init(workingDirectory: String = FileManager.default.currentDirectoryPath, timeout: TimeInterval = 30) {
        self.workingDirectory = workingDirectory
        self.timeout = timeout
    }
    
    var definitions: [AIToolDefinition] {
        [
            AIToolDefinition(
                name: "shell_run",
                description: "Run a shell command and return its output. Runs in the background, not in the visible terminal.",
                parameters: .init(
                    properties: [
                        "command": .init(type: "string", description: "The shell command to execute")
                    ],
                    required: ["command"]
                )
            ),
            AIToolDefinition(
                name: "shell_which",
                description: "Find the path to an executable",
                parameters: .init(
                    properties: [
                        "program": .init(type: "string", description: "The program name to find")
                    ],
                    required: ["program"]
                )
            ),
            AIToolDefinition(
                name: "shell_env",
                description: "Get the value of an environment variable",
                parameters: .init(
                    properties: [
                        "name": .init(type: "string", description: "The environment variable name")
                    ],
                    required: ["name"]
                )
            )
        ]
    }
    
    func call(name: String, arguments: [String: JSONValue]) async throws -> String {
        switch name {
        case "shell_run":
            let command = arguments["command"]!.stringValue!
            return try await run(command: command)
        case "shell_which":
            let program = arguments["program"]!.stringValue!
            return which(program: program)
        case "shell_env":
            let envName = arguments["name"]!.stringValue!
            return env(name: envName)
        default:
            throw AIToolError.unknownTool(name)
        }
    }
    
    // MARK: - Tool Methods
    
    func run(command: String) async throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]
        task.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe
        
        try task.run()
        
        // Wait with timeout
        let deadline = Date().addingTimeInterval(timeout)
        while task.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        if task.isRunning {
            task.terminate()
            return "Error: Command timed out after \(Int(timeout)) seconds"
        }
        
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        
        var result = ""
        if !stdout.isEmpty {
            result += stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !stderr.isEmpty {
            if !result.isEmpty { result += "\n" }
            result += "stderr: \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        
        let exitCode = task.terminationStatus
        if exitCode != 0 {
            result += "\n[exit code: \(exitCode)]"
        }
        
        // Truncate very long output
        if result.count > 20000 {
            result = String(result.prefix(20000)) + "\n... [truncated]"
        }
        
        return result.isEmpty ? "(no output)" : result
    }
    
    func which(program: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [program]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if output.isEmpty {
                return "\(program) not found"
            }
            return output
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    func env(name: String) -> String {
        if let value = ProcessInfo.processInfo.environment[name] {
            return "\(name)=\(value)"
        }
        return "\(name) is not set"
    }
}
