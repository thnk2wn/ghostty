import Foundation

/// OpenAI model implementation
public final class OpenAIModel: AIAgentModel, @unchecked Sendable {
    public let modelId: String
    public let provider = "openai"
    
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession
    
    public var displayName: String {
        switch modelId {
        case "gpt-4o": return "GPT-4o"
        case "gpt-4o-mini": return "GPT-4o Mini"
        case "gpt-4-turbo": return "GPT-4 Turbo"
        case "o1": return "o1"
        case "o1-mini": return "o1 Mini"
        case "o3-mini": return "o3 Mini"
        default: return modelId
        }
    }
    
    public init(
        modelId: String = "gpt-4o",
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!
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
        var messages: [[String: Any]] = []
        
        if let system = systemPrompt {
            messages.append(["role": "system", "content": system])
        }
        messages.append(["role": "user", "content": prompt])
        
        // Build request body
        var body: [String: Any] = [
            "model": modelId,
            "messages": messages,
            "stream": streamHandler != nil
        ]
        
        if let temp = temperature {
            body["temperature"] = Double(temp)
        }
        
        if let max = maxTokens {
            body["max_tokens"] = max
        }
        
        // Add tools if provided
        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { tool -> [String: Any] in
                [
                    "type": "function",
                    "function": tool.jsonDict
                ]
            }
        }
        
        // Add response format for structured output
        if let schema = outputSchema, let schemaData = schema.data(using: .utf8),
           let schemaJson = try? JSONSerialization.jsonObject(with: schemaData) {
            body["response_format"] = [
                "type": "json_schema",
                "json_schema": [
                    "name": "response",
                    "schema": schemaJson
                ]
            ]
        }
        
        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw AIModelError.invalidResponse
        }
        
        return parseMessage(message)
    }
    
    // MARK: - Streaming Request
    
    private func streamRequest(
        _ request: URLRequest,
        streamHandler: @escaping (String) -> Void
    ) async throws -> [AIAgentOutput] {
        AIAgentLogger.network.info("Starting streaming request to OpenAI")
        let startTime = Date()
        
        let (bytes, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            AIAgentLogger.network.error("Invalid response type from OpenAI")
            throw AIModelError.invalidResponse
        }
        
        AIAgentLogger.network.info("OpenAI response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            AIAgentLogger.network.error("OpenAI HTTP error \(httpResponse.statusCode): \(errorMessage)")
            throw AIModelError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        var fullContent = ""
        var toolCalls: [PartialToolCall] = []
        var lastChunkTime = Date()
        var chunkCount = 0
        
        AIAgentLogger.streaming.info("Beginning to process stream chunks")
        
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
                
                if jsonStr == "[DONE]" {
                    AIAgentLogger.streaming.info("Stream completed with [DONE]")
                    break
                }
                
                guard let jsonData = jsonStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let delta = firstChoice["delta"] as? [String: Any] else {
                    continue
                }
                
                // Check for finish_reason
                if let finishReason = firstChoice["finish_reason"] as? String {
                    AIAgentLogger.streaming.info("Stream finish_reason: \(finishReason)")
                    if finishReason == "stop" || finishReason == "length" {
                        break
                    }
                }
                
                // Handle content
                if let content = delta["content"] as? String {
                    fullContent += content
                    streamHandler(content)
                }
                
                // Handle tool calls
                if let deltaToolCalls = delta["tool_calls"] as? [[String: Any]] {
                    for toolCall in deltaToolCalls {
                        guard let index = toolCall["index"] as? Int else { continue }
                        
                        // Ensure we have enough slots
                        while toolCalls.count <= index {
                            toolCalls.append(PartialToolCall())
                        }
                        
                        if let id = toolCall["id"] as? String {
                            toolCalls[index].id = id
                        }
                        if let function = toolCall["function"] as? [String: Any] {
                            if let name = function["name"] as? String {
                                toolCalls[index].name = name
                            }
                            if let args = function["arguments"] as? String {
                                toolCalls[index].arguments += args
                            }
                        }
                    }
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
        AIAgentLogger.streaming.info("Stream completed: \(chunkCount) chunks, \(fullContent.count) chars, \(String(format: "%.2f", elapsed))s")
        
        var outputs: [AIAgentOutput] = []
        
        if !fullContent.isEmpty {
            outputs.append(.text(fullContent))
        }
        
        for toolCall in toolCalls where toolCall.name != nil {
            if let call = AIAgentOutput.FunctionCall(
                jsonString: "{\"name\":\"\(toolCall.name!)\",\"args\":\(toolCall.arguments.isEmpty ? "{}" : toolCall.arguments)}"
            ) {
                outputs.append(.functionCall(call))
                AIAgentLogger.tools.info("Tool call parsed: \(toolCall.name!)")
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
    
    private func parseMessage(_ message: [String: Any]) -> [AIAgentOutput] {
        var outputs: [AIAgentOutput] = []
        
        if let content = message["content"] as? String {
            outputs.append(.text(content))
        }
        
        if let toolCalls = message["tool_calls"] as? [[String: Any]] {
            for toolCall in toolCalls {
                guard let function = toolCall["function"] as? [String: Any],
                      let name = function["name"] as? String,
                      let arguments = function["arguments"] as? String else {
                    continue
                }
                
                if let call = AIAgentOutput.FunctionCall(
                    jsonString: "{\"name\":\"\(name)\",\"args\":\(arguments)}"
                ) {
                    outputs.append(.functionCall(call))
                }
            }
        }
        
        return outputs
    }
    
    private struct PartialToolCall {
        var id: String?
        var name: String?
        var arguments: String = ""
    }
}
