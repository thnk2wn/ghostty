import Foundation
import GhosttyKit

/// Terminal-specific tools for Ghostty
struct TerminalTools: AITool, @unchecked Sendable {
    private weak var surface: Ghostty.SurfaceView?
    
    init(surface: Ghostty.SurfaceView?) {
        self.surface = surface
    }
    
    var definitions: [AIToolDefinition] {
        [
            AIToolDefinition(
                name: "execute_command",
                description: "Execute a shell command in the terminal. The command will run in the user's current shell environment.",
                parameters: .init(
                    properties: [
                        "command": .init(type: "string", description: "The shell command to execute")
                    ],
                    required: ["command"]
                )
            ),
            AIToolDefinition(
                name: "read_file",
                description: "Read the contents of a file",
                parameters: .init(
                    properties: [
                        "path": .init(type: "string", description: "The file path to read")
                    ],
                    required: ["path"]
                )
            ),
            AIToolDefinition(
                name: "write_file",
                description: "Write content to a file",
                parameters: .init(
                    properties: [
                        "path": .init(type: "string", description: "The file path to write to"),
                        "content": .init(type: "string", description: "The content to write")
                    ],
                    required: ["path", "content"]
                )
            ),
            AIToolDefinition(
                name: "list_directory",
                description: "List the contents of a directory",
                parameters: .init(
                    properties: [
                        "path": .init(type: "string", description: "The directory path to list")
                    ],
                    required: ["path"]
                )
            ),
            AIToolDefinition(
                name: "get_current_directory",
                description: "Get the current working directory",
                parameters: .init()
            ),
            AIToolDefinition(
                name: "search_files",
                description: "Search for files matching a pattern in a directory",
                parameters: .init(
                    properties: [
                        "directory": .init(type: "string", description: "The directory to search in"),
                        "pattern": .init(type: "string", description: "The glob pattern to match (e.g., *.swift)")
                    ],
                    required: ["directory", "pattern"]
                )
            )
        ]
    }
    
    func call(name: String, arguments: [String: JSONValue]) async throws -> String {
        switch name {
        case "execute_command":
            return try await executeCommand(arguments)
        case "read_file":
            return try readFile(arguments)
        case "write_file":
            return try writeFile(arguments)
        case "list_directory":
            return try listDirectory(arguments)
        case "get_current_directory":
            return getCurrentDirectory()
        case "search_files":
            return try searchFiles(arguments)
        default:
            throw AIToolError.unknownTool(name)
        }
    }
    
    // MARK: - Tool Implementations
    
    private func executeCommand(_ arguments: [String: JSONValue]) async throws -> String {
        guard let command = arguments["command"]?.stringValue else {
            throw AIToolError.invalidArguments("Missing 'command' argument")
        }
        
        guard let surface = surface?.surface else {
            throw AIToolError.executionFailed("Terminal surface not available")
        }
        
        // Send the command to the terminal
        let commandWithNewline = command + "\r"
        let success = commandWithNewline.withCString { ptr in
            ghostty_agent_send_input(surface, ptr, commandWithNewline.utf8.count)
        }
        
        if success {
            return "Command sent to terminal: \(command)"
        } else {
            throw AIToolError.executionFailed("Failed to send command to terminal")
        }
    }
    
    private func readFile(_ arguments: [String: JSONValue]) throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            throw AIToolError.invalidArguments("Missing 'path' argument")
        }
        
        let expandedPath = (path as NSString).expandingTildeInPath
        
        do {
            let content = try String(contentsOfFile: expandedPath, encoding: .utf8)
            // Truncate very long files
            if content.count > 50000 {
                return String(content.prefix(50000)) + "\n... (truncated, file is \(content.count) characters)"
            }
            return content
        } catch {
            throw AIToolError.executionFailed("Failed to read file: \(error.localizedDescription)")
        }
    }
    
    private func writeFile(_ arguments: [String: JSONValue]) throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            throw AIToolError.invalidArguments("Missing 'path' argument")
        }
        guard let content = arguments["content"]?.stringValue else {
            throw AIToolError.invalidArguments("Missing 'content' argument")
        }
        
        let expandedPath = (path as NSString).expandingTildeInPath
        
        do {
            try content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
            return "Successfully wrote \(content.count) characters to \(path)"
        } catch {
            throw AIToolError.executionFailed("Failed to write file: \(error.localizedDescription)")
        }
    }
    
    private func listDirectory(_ arguments: [String: JSONValue]) throws -> String {
        guard let path = arguments["path"]?.stringValue else {
            throw AIToolError.invalidArguments("Missing 'path' argument")
        }
        
        let expandedPath = (path as NSString).expandingTildeInPath
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: expandedPath)
            let detailed = contents.map { item -> String in
                let itemPath = (expandedPath as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir)
                return isDir.boolValue ? "\(item)/" : item
            }.sorted()
            return detailed.joined(separator: "\n")
        } catch {
            throw AIToolError.executionFailed("Failed to list directory: \(error.localizedDescription)")
        }
    }
    
    private func getCurrentDirectory() -> String {
        return FileManager.default.currentDirectoryPath
    }
    
    private func searchFiles(_ arguments: [String: JSONValue]) throws -> String {
        guard let directory = arguments["directory"]?.stringValue else {
            throw AIToolError.invalidArguments("Missing 'directory' argument")
        }
        guard let pattern = arguments["pattern"]?.stringValue else {
            throw AIToolError.invalidArguments("Missing 'pattern' argument")
        }
        
        let expandedPath = (directory as NSString).expandingTildeInPath
        
        // Simple glob matching using shell
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "find '\(expandedPath)' -name '\(pattern)' -type f 2>/dev/null | head -100"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if output.isEmpty {
                return "No files found matching '\(pattern)' in \(directory)"
            }
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw AIToolError.executionFailed("Search failed: \(error.localizedDescription)")
        }
    }
}
