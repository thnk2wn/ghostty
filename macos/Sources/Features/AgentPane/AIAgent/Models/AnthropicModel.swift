import Foundation

/// Anthropic Claude model implementation
public final class AnthropicModel: AIAgentModel, @unchecked Sendable {
    public let modelId: String
    public let provider = "anthropic"
    
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    private let apiVersion = "2023-06-01"
    
    public var displayName: String {
        switch modelId {
        case "claude-sonnet-4-20250514": return "Claude Sonnet 4"
        case "claude-3-5-sonnet-20241022": return "Claude 3.5 Sonnet"
        case "claude-3-5-haiku-20241022": return "Claude 3.5 Haiku"
        case "claude-3-opus-20240229": return "Claude 3 Opus"
        default: return modelId
        }
    }
    
    public init(
        modelId: String = "claude-sonnet-4-20250514",
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com/v1")!
    ) {
        self.modelId = modelId
        self.apiKey = apiKey
        self.baseURL = baseURL
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }
    
    public func run(
        prompt: String,
        systemPrompt: String?,
        tools: [AIToolDefinition]?,
        outputSchema: String?,
        temperature: Float?,
        maxTokens: Int?,
        streamHandler: ((String) -> Void)?
    ) async throws -> [AIAgentOutput] {
        // Anthropic uses a different message format
        let messages: [[String: Any]] = [
            ["role": "user", "content": prompt]
        ]
        
        // Build request body
        var body: [String: Any] = [
            "model": modelId,
            "messages": messages,
            "max_tokens": maxTokens ?? 4096,
            "stream": streamHandler != nil
        ]
        
        if let system = systemPrompt {
            body["system"] = system
        }
        
        if let temp = temperature {
            body["temperature"] = Double(temp)
        }
        
        // Add tools if provided
        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { tool -> [String: Any] in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "input_schema": [
                        "type": tool.parameters.type,
                        "properties": tool.parameters.properties.mapValues { prop -> [String: Any] in
                            var dict: [String: Any] = ["type": prop.type]
                            if let desc = prop.description {
                                dict["description"] = desc
                            }
                            if let enumVals = prop.enumValues {
                                dict["enum"] = enumVals
                            }
                            return dict
                        },
                        "required": tool.parameters.required
                    ]
                ]
            }
        }
        
        let url = baseURL.appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        if streamHandler != nil {
            return try await streamRequest(request, streamHandler: streamHandler!)
        } else {
            return try await nonStreamingRequest(request)
        }
    }
    
    // MARK: - Non-Streaming Request
    
    private func nonStreamingRequest(_ request: URLRequest) async throws -> [AIAgentOutput] {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIModelError.invalidResponse
        }
        
        try checkStatusCode(httpResponse, data: data)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw AIModelError.invalidResponse
        }
        
        return parseContent(content)
    }
    
    // MARK: - Streaming Request
    
    private func streamRequest(
        _ request: URLRequest,
        streamHandler: @escaping (String) -> Void
    ) async throws -> [AIAgentOutput] {
        AIAgentLogger.network.info("Starting streaming request to Anthropic")
        let startTime = Date()
        
        let (bytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            AIAgentLogger.network.error("Invalid response type from Anthropic")
            throw AIModelError.invalidResponse
        }
        
        AIAgentLogger.network.info("Anthropic response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            AIAgentLogger.network.error("Anthropic HTTP error \(httpResponse.statusCode): \(errorMessage)")
            throw AIModelError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        var fullContent = ""
        var currentToolUse: PartialToolUse?
        var toolUses: [PartialToolUse] = []
        var lastChunkTime = Date()
        var chunkCount = 0
        
        AIAgentLogger.streaming.info("Beginning to process Anthropic stream chunks")
        
        do {
            for try await line in bytes.lines {
                // Check for cancellation
                try Task.checkCancellation()
                
                // Check for stalled stream (no data for 60 seconds)
                let now = Date()
                let timeSinceLastChunk = now.timeIntervalSince(lastChunkTime)
                if timeSinceLastChunk > 60 {
                    AIAgentLogger.streaming.error("Stream stalled - no data for \(Int(timeSinceLastChunk)) seconds")
                    throw AIModelError.timeout
                }
                lastChunkTime = now
                chunkCount += 1
                
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))
                
                guard let jsonData = jsonStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let eventType = json["type"] as? String else {
                    continue
                }
                
                switch eventType {
                case "message_start":
                    AIAgentLogger.streaming.debug("Anthropic message_start received")
                    
                case "content_block_start":
                    if let contentBlock = json["content_block"] as? [String: Any],
                       let blockType = contentBlock["type"] as? String {
                        if blockType == "tool_use" {
                            currentToolUse = PartialToolUse(
                                id: contentBlock["id"] as? String ?? "",
                                name: contentBlock["name"] as? String ?? ""
                            )
                            AIAgentLogger.tools.info("Tool use started: \(currentToolUse?.name ?? "unknown")")
                        }
                    }
                    
                case "content_block_delta":
                    if let delta = json["delta"] as? [String: Any],
                       let deltaType = delta["type"] as? String {
                        if deltaType == "text_delta", let text = delta["text"] as? String {
                            fullContent += text
                            streamHandler(text)
                        } else if deltaType == "input_json_delta",
                                  let partialJson = delta["partial_json"] as? String {
                            currentToolUse?.inputJson += partialJson
                        }
                    }
                    
                case "content_block_stop":
                    if let tool = currentToolUse {
                        toolUses.append(tool)
                        AIAgentLogger.tools.info("Tool use completed: \(tool.name)")
                        currentToolUse = nil
                    }
                    
                case "message_stop":
                    AIAgentLogger.streaming.info("Anthropic message_stop received")
                    
                case "message_delta":
                    if let delta = json["delta"] as? [String: Any],
                       let stopReason = delta["stop_reason"] as? String {
                        AIAgentLogger.streaming.info("Anthropic stop_reason: \(stopReason)")
                    }
                    
                default:
                    break
                }
            }
        } catch is CancellationError {
            AIAgentLogger.streaming.warning("Stream cancelled after \(chunkCount) chunks")
            throw AIModelError.cancelled
        } catch let error as AIModelError {
            throw error
        } catch {
            AIAgentLogger.streaming.error("Stream error: \(error.localizedDescription)")
            throw AIModelError.streamingError(error.localizedDescription)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        AIAgentLogger.streaming.info("Anthropic stream completed: \(chunkCount) chunks, \(fullContent.count) chars, \(String(format: "%.2f", elapsed))s")
        
        var outputs: [AIAgentOutput] = []
        
        if !fullContent.isEmpty {
            outputs.append(.text(fullContent))
        }
        
        for toolUse in toolUses {
            if let call = AIAgentOutput.FunctionCall(
                jsonString: "{\"name\":\"\(toolUse.name)\",\"args\":\(toolUse.inputJson.isEmpty ? "{}" : toolUse.inputJson)}"
            ) {
                outputs.append(.functionCall(call))
            }
        }
        
        return outputs
    }
    
    // MARK: - Helpers
    
    private func checkStatusCode(_ response: HTTPURLResponse, data: Data) throws {
        guard (200...299).contains(response.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            if response.statusCode == 429 {
                let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Double($0) }
                throw AIModelError.rateLimited(retryAfter: retryAfter)
            }
            
            throw AIModelError.httpError(statusCode: response.statusCode, message: errorMessage)
        }
    }
    
    private func parseContent(_ content: [[String: Any]]) -> [AIAgentOutput] {
        var outputs: [AIAgentOutput] = []
        
        for block in content {
            guard let type = block["type"] as? String else { continue }
            
            switch type {
            case "text":
                if let text = block["text"] as? String {
                    outputs.append(.text(text))
                }
                
            case "tool_use":
                if let name = block["name"] as? String,
                   let input = block["input"] as? [String: Any],
                   let inputData = try? JSONSerialization.data(withJSONObject: input),
                   let inputStr = String(data: inputData, encoding: .utf8) {
                    if let call = AIAgentOutput.FunctionCall(
                        jsonString: "{\"name\":\"\(name)\",\"args\":\(inputStr)}"
                    ) {
                        outputs.append(.functionCall(call))
                    }
                }
                
            default:
                break
            }
        }
        
        return outputs
    }
    
    private struct PartialToolUse {
        let id: String
        let name: String
        var inputJson: String = ""
    }
}
