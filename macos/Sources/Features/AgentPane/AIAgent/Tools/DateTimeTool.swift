import Foundation

/// Tool for getting current date and time information
struct DateTimeTool: AITool {
    
    var definitions: [AIToolDefinition] {
        [
            AIToolDefinition(
                name: "datetime_now",
                description: "Get the current date and time in various formats (ISO 8601, readable, unix timestamp)",
                parameters: .init()
            ),
            AIToolDefinition(
                name: "datetime_format",
                description: "Format a unix timestamp into a readable date string",
                parameters: .init(
                    properties: [
                        "timestamp": .init(type: "number", description: "Unix timestamp (seconds since epoch)"),
                        "format": .init(type: "string", description: "Optional date format string (e.g., 'yyyy-MM-dd HH:mm:ss')")
                    ],
                    required: ["timestamp"]
                )
            ),
            AIToolDefinition(
                name: "datetime_parse",
                description: "Parse a date string and return unix timestamp",
                parameters: .init(
                    properties: [
                        "date": .init(type: "string", description: "The date string to parse"),
                        "format": .init(type: "string", description: "The format of the date string (e.g., 'yyyy-MM-dd')")
                    ],
                    required: ["date", "format"]
                )
            )
        ]
    }
    
    func call(name: String, arguments: [String: JSONValue]) async throws -> String {
        switch name {
        case "datetime_now":
            return now()
        case "datetime_format":
            let ts = arguments["timestamp"]!.doubleValue!
            let fmt = arguments["format"]?.stringValue
            return format(timestamp: ts, format: fmt)
        case "datetime_parse":
            let date = arguments["date"]!.stringValue!
            let fmt = arguments["format"]!.stringValue!
            return parse(date: date, format: fmt)
        default:
            throw AIToolError.unknownTool(name)
        }
    }
    
    // MARK: - Tool Methods
    
    func now() -> String {
        let date = Date()
        let iso = ISO8601DateFormatter().string(from: date)
        
        let readable = DateFormatter()
        readable.dateStyle = .full
        readable.timeStyle = .long
        
        return """
        Current date and time:
        ISO 8601: \(iso)
        Readable: \(readable.string(from: date))
        Unix timestamp: \(Int(date.timeIntervalSince1970))
        Timezone: \(TimeZone.current.identifier)
        """
    }
    
    func format(timestamp: Double, format: String?) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = format ?? "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    func parse(date: String, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        
        if let parsed = formatter.date(from: date) {
            return "Unix timestamp: \(Int(parsed.timeIntervalSince1970))"
        } else {
            return "Error: Could not parse '\(date)' with format '\(format)'"
        }
    }
}
