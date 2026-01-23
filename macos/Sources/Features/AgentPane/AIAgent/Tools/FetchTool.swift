import Foundation

/// Tool for fetching content from URLs
struct FetchTool: AITool {
    
    private let session: URLSession
    
    init() {
        // Configure URLSession with reasonable timeouts and TLS settings
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        // Add common headers
        config.httpAdditionalHeaders = [
            "User-Agent": "Ghostty/1.0"
        ]
        self.session = URLSession(configuration: config)
    }
    
    var definitions: [AIToolDefinition] {
        [
            AIToolDefinition(
                name: "fetch",
                description: "Fetch the text content of a URL. Returns the readable text extracted from the page.",
                parameters: .init(
                    properties: [
                        "url": .init(type: "string", description: "The URL to fetch")
                    ],
                    required: ["url"]
                )
            ),
            AIToolDefinition(
                name: "fetch_json",
                description: "Fetch JSON from a URL and return it pretty-printed.",
                parameters: .init(
                    properties: [
                        "url": .init(type: "string", description: "The URL to fetch JSON from")
                    ],
                    required: ["url"]
                )
            ),
            AIToolDefinition(
                name: "fetch_headers",
                description: "Fetch only the HTTP headers from a URL (HEAD request).",
                parameters: .init(
                    properties: [
                        "url": .init(type: "string", description: "The URL to check")
                    ],
                    required: ["url"]
                )
            )
        ]
    }
    
    func call(name: String, arguments: [String: JSONValue]) async throws -> String {
        let urlString = arguments["url"]!.stringValue!
        
        switch name {
        case "fetch":
            return try await fetch(url: urlString)
        case "fetch_json":
            return try await fetchJSON(url: urlString)
        case "fetch_headers":
            return try await fetchHeaders(url: urlString)
        default:
            throw AIToolError.unknownTool(name)
        }
    }
    
    // MARK: - Tool Methods
    
    func fetch(url urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            return "Error: Invalid URL '\(urlString)'"
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "Error: Invalid response"
            }
            
            guard 200..<300 ~= httpResponse.statusCode else {
                return "Error: HTTP \(httpResponse.statusCode)"
            }
            
            guard let html = String(data: data, encoding: .utf8) else {
                return "Error: Could not decode response as UTF-8"
            }
            
            let text = extractText(from: html)
            // Limit to 4000 chars to not overwhelm the AI
            let maxLength = 4000
            
            if text.count > maxLength {
                return "Content from \(urlString) (truncated):\n\n\(String(text.prefix(maxLength)))..."
            }
            return "Content from \(urlString):\n\n\(text)"
        } catch {
            return "Error fetching \(urlString): \(error.localizedDescription)"
        }
    }
    
    func fetchJSON(url urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            return "Error: Invalid URL '\(urlString)'"
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Ghostty/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "Error: Invalid response"
            }
            
            guard 200..<300 ~= httpResponse.statusCode else {
                return "Error: HTTP \(httpResponse.statusCode)"
            }
            
            let json = try JSONSerialization.jsonObject(with: data)
            let pretty = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            guard let result = String(data: pretty, encoding: .utf8) else {
                return "Error: Could not format JSON"
            }
            
            // Limit to 4000 chars so the AI can process and summarize
            let maxLength = 4000
            if result.count > maxLength {
                return "JSON data (truncated to key fields):\n\n\(String(result.prefix(maxLength)))..."
            }
            return "JSON data:\n\n\(result)"
        } catch {
            return "Error fetching \(urlString): \(error.localizedDescription)"
        }
    }
    
    func fetchHeaders(url urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            return "Error: Invalid URL '\(urlString)'"
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "Error: Invalid response"
            }
            
            var result = "HTTP \(httpResponse.statusCode)\n"
            for (key, value) in httpResponse.allHeaderFields {
                result += "\(key): \(value)\n"
            }
            return result
        } catch {
            return "Error fetching headers: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helpers
    
    private func extractText(from html: String) -> String {
        var text = html
        
        // Remove script, style, and other non-content tags
        let removePatterns = [
            "<script[^>]*>[\\s\\S]*?</script>",
            "<style[^>]*>[\\s\\S]*?</style>",
            "<head[^>]*>[\\s\\S]*?</head>",
            "<nav[^>]*>[\\s\\S]*?</nav>",
            "<footer[^>]*>[\\s\\S]*?</footer>",
            "<!--[\\s\\S]*?-->"
        ]
        
        for pattern in removePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            }
        }
        
        // Replace block elements with newlines
        let blockTags = ["</p>", "</div>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>", "<br>", "<br/>", "</li>", "</tr>"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }
        
        // Remove all HTML tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }
        
        // Decode common HTML entities
        text = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        
        // Clean up whitespace
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        return lines.joined(separator: "\n")
    }
}
