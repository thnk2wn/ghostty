import Foundation

/// File I/O tool for reading and writing files relative to a base folder
struct FileIOTool: AITool {
    let baseFolder: String
    
    init(baseFolder: String = FileManager.default.currentDirectoryPath) {
        self.baseFolder = baseFolder
    }
    
    var definitions: [AIToolDefinition] {
        [
            AIToolDefinition(
                name: "file_read",
                description: "Read content of a file. Path is relative to the current working directory.",
                parameters: .init(
                    properties: [
                        "file": .init(type: "string", description: "The file path to read")
                    ],
                    required: ["file"]
                )
            ),
            AIToolDefinition(
                name: "file_write",
                description: "Write content to a file. Path is relative to the current working directory.",
                parameters: .init(
                    properties: [
                        "file": .init(type: "string", description: "The file path to write to"),
                        "content": .init(type: "string", description: "The content to write")
                    ],
                    required: ["file", "content"]
                )
            ),
            AIToolDefinition(
                name: "file_append",
                description: "Append content to the end of a file.",
                parameters: .init(
                    properties: [
                        "file": .init(type: "string", description: "The file path to append to"),
                        "content": .init(type: "string", description: "The content to append")
                    ],
                    required: ["file", "content"]
                )
            ),
            AIToolDefinition(
                name: "file_exists",
                description: "Check if a file or directory exists.",
                parameters: .init(
                    properties: [
                        "path": .init(type: "string", description: "The path to check")
                    ],
                    required: ["path"]
                )
            ),
            AIToolDefinition(
                name: "file_delete",
                description: "Delete a file.",
                parameters: .init(
                    properties: [
                        "file": .init(type: "string", description: "The file path to delete")
                    ],
                    required: ["file"]
                )
            )
        ]
    }
    
    func call(name: String, arguments: [String: JSONValue]) async throws -> String {
        switch name {
        case "file_read":
            return try read(file: arguments["file"]!.stringValue!)
        case "file_write":
            return try write(file: arguments["file"]!.stringValue!, content: arguments["content"]!.stringValue!)
        case "file_append":
            return try append(file: arguments["file"]!.stringValue!, content: arguments["content"]!.stringValue!)
        case "file_exists":
            return exists(path: arguments["path"]!.stringValue!)
        case "file_delete":
            return try delete(file: arguments["file"]!.stringValue!)
        default:
            throw AIToolError.unknownTool(name)
        }
    }
    
    // MARK: - Tool Methods
    
    func read(file: String) throws -> String {
        let fileURL = resolveURL(file)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        
        if content.count > 50000 {
            return "Content of \(file):\n\(String(content.prefix(50000)))\n... [truncated, \(content.count) total characters]"
        }
        return "Content of \(file):\n\(content)"
    }
    
    func write(file: String, content: String) throws -> String {
        let fileURL = resolveURL(file)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return "Successfully wrote \(content.count) characters to \(file)"
    }
    
    func append(file: String, content: String) throws -> String {
        let fileURL = resolveURL(file)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            handle.seekToEndOfFile()
            handle.write(content.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return "Successfully appended \(content.count) characters to \(file)"
    }
    
    func exists(path: String) -> String {
        let fileURL = resolveURL(path)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory)
        
        if exists {
            return isDirectory.boolValue ? "\(path) exists (directory)" : "\(path) exists (file)"
        } else {
            return "\(path) does not exist"
        }
    }
    
    func delete(file: String) throws -> String {
        let fileURL = resolveURL(file)
        try FileManager.default.removeItem(at: fileURL)
        return "Successfully deleted \(file)"
    }
    
    // MARK: - Helpers
    
    private func resolveURL(_ path: String) -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded)
        }
        return URL(fileURLWithPath: baseFolder).appendingPathComponent(path)
    }
}
