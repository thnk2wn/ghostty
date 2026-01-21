import Foundation

enum AIProviderType {
    case openai
    case anthropic
    case ollama

    static func from(model: String) -> AIProviderType {
        if model.contains("claude") {
            return .anthropic
        } else if model.contains("llama") || model.contains("mistral") || model.contains("codellama") || model.contains("mixtral") {
            return .ollama
        }
        return .openai
    }

    var name: String {
        switch self {
        case .openai: return "openai"
        case .anthropic: return "anthropic"
        case .ollama: return "ollama"
        }
    }
}

struct AIMessage: Codable {
    let role: String
    let content: String
}

struct AIRequest {
    let messages: [AIMessage]
    let model: String
    let stream: Bool
    let temperature: Double?
}

struct AIResponse {
    let content: String
    let finishReason: String?
    let usage: Usage?

    struct Usage {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
    }
}

enum AIClientError: Error, LocalizedError {
    case missingAPIKey(provider: String)
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)
    case ollamaNotRunning

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider). Configure it in AI Settings."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .ollamaNotRunning:
            return "Ollama server is not running. Start it with `ollama serve`."
        }
    }
}

class AIClient {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    func sendRequest(
        _ request: AIRequest,
        streamHandler: ((String) -> Void)? = nil,
        completion: @escaping (Result<AIResponse, AIClientError>) -> Void
    ) {
        let provider = AIProviderType.from(model: request.model)

        switch provider {
        case .openai:
            sendOpenAIRequest(request, streamHandler: streamHandler, completion: completion)
        case .anthropic:
            sendAnthropicRequest(request, streamHandler: streamHandler, completion: completion)
        case .ollama:
            sendOllamaRequest(request, streamHandler: streamHandler, completion: completion)
        }
    }

    private func sendOpenAIRequest(
        _ request: AIRequest,
        streamHandler: ((String) -> Void)?,
        completion: @escaping (Result<AIResponse, AIClientError>) -> Void
    ) {
        guard let apiKey = getAPIKey(provider: "openai") else {
            completion(.failure(.missingAPIKey(provider: "OpenAI")))
            return
        }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(.invalidURL))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": request.model,
            "messages": request.messages.map { ["role": $0.role, "content": $0.content] },
            "stream": request.stream,
            "temperature": request.temperature ?? 0.7
        ]

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.decodingError(error)))
            return
        }

        if request.stream {
            handleStreamingRequest(urlRequest, isOpenAI: true, streamHandler: streamHandler, completion: completion)
        } else {
            handleNonStreamingRequest(urlRequest, isOpenAI: true, completion: completion)
        }
    }

    private func sendAnthropicRequest(
        _ request: AIRequest,
        streamHandler: ((String) -> Void)?,
        completion: @escaping (Result<AIResponse, AIClientError>) -> Void
    ) {
        guard let apiKey = getAPIKey(provider: "anthropic") else {
            completion(.failure(.missingAPIKey(provider: "Anthropic")))
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            completion(.failure(.invalidURL))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let systemMessage = request.messages.first?.role == "system" ? request.messages.first?.content : nil
        let userMessages = systemMessage != nil ? Array(request.messages.dropFirst()) : request.messages

        let body: [String: Any] = [
            "model": request.model,
            "messages": userMessages.map { ["role": $0.role, "content": $0.content] },
            "stream": request.stream,
            "max_tokens": 4096,
            "temperature": request.temperature ?? 0.7,
            "system": systemMessage ?? ""
        ]

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.decodingError(error)))
            return
        }

        if request.stream {
            handleStreamingRequest(urlRequest, isOpenAI: false, streamHandler: streamHandler, completion: completion)
        } else {
            handleNonStreamingRequest(urlRequest, isOpenAI: false, completion: completion)
        }
    }

    private func handleNonStreamingRequest(
        _ request: URLRequest,
        isOpenAI: Bool,
        completion: @escaping (Result<AIResponse, AIClientError>) -> Void
    ) {
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                completion(.failure(.httpError(statusCode: httpResponse.statusCode, message: errorMessage)))
                return
            }

            do {
                if isOpenAI {
                    let result = try self.parseOpenAIResponse(data)
                    completion(.success(result))
                } else {
                    let result = try self.parseAnthropicResponse(data)
                    completion(.success(result))
                }
            } catch let error as AIClientError {
                completion(.failure(error))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }

        task.resume()
    }

    private func handleStreamingRequest(
        _ request: URLRequest,
        isOpenAI: Bool,
        streamHandler: ((String) -> Void)?,
        completion: @escaping (Result<AIResponse, AIClientError>) -> Void
    ) {
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                completion(.failure(.httpError(statusCode: httpResponse.statusCode, message: errorMessage)))
                return
            }

            guard let text = String(data: data, encoding: .utf8) else {
                completion(.failure(.invalidResponse))
                return
            }

            var fullContent = ""
            let lines = text.components(separatedBy: "\n")

            for line in lines {
                if line.hasPrefix("data: ") {
                    let jsonStr = String(line.dropFirst(6))
                    if jsonStr == "[DONE]" { continue }

                    guard let jsonData = jsonStr.data(using: .utf8) else { continue }

                    do {
                        if isOpenAI {
                            if let chunk = try self.parseOpenAIStreamChunk(jsonData) {
                                fullContent += chunk
                                streamHandler?(chunk)
                            }
                        } else {
                            if let chunk = try self.parseAnthropicStreamChunk(jsonData) {
                                fullContent += chunk
                                streamHandler?(chunk)
                            }
                        }
                    } catch {
                        continue
                    }
                }
            }

            let response = AIResponse(content: fullContent, finishReason: "stop", usage: nil)
            completion(.success(response))
        }

        task.resume()
    }

    private func parseOpenAIResponse(_ data: Data) throws -> AIResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIClientError.invalidResponse
        }

        let finishReason = firstChoice["finish_reason"] as? String

        var usage: AIResponse.Usage?
        if let usageData = json["usage"] as? [String: Any],
           let promptTokens = usageData["prompt_tokens"] as? Int,
           let completionTokens = usageData["completion_tokens"] as? Int,
           let totalTokens = usageData["total_tokens"] as? Int {
            usage = AIResponse.Usage(
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                totalTokens: totalTokens
            )
        }

        return AIResponse(content: content, finishReason: finishReason, usage: usage)
    }

    private func parseAnthropicResponse(_ data: Data) throws -> AIResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw AIClientError.invalidResponse
        }

        let stopReason = json["stop_reason"] as? String

        var usage: AIResponse.Usage?
        if let usageData = json["usage"] as? [String: Any],
           let inputTokens = usageData["input_tokens"] as? Int,
           let outputTokens = usageData["output_tokens"] as? Int {
            usage = AIResponse.Usage(
                promptTokens: inputTokens,
                completionTokens: outputTokens,
                totalTokens: inputTokens + outputTokens
            )
        }

        return AIResponse(content: text, finishReason: stopReason, usage: usage)
    }

    private func parseOpenAIStreamChunk(_ data: Data) throws -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let delta = firstChoice["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }
        return content
    }

    private func parseAnthropicStreamChunk(_ data: Data) throws -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        if type == "content_block_delta",
           let delta = json["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            return text
        }

        return nil
    }

    /// Get API key using resolution order: Keychain -> Config file -> Environment variable
    private func getAPIKey(provider: String) -> String? {
        return AgentConfig.getAPIKey(for: provider.lowercased())
    }

    /// Get the Ollama base URL from config
    private func getOllamaUrl() -> String {
        if let url = ConfigFileWriter.readValue(key: "ai-agent-ollama-url"), !url.isEmpty {
            return url
        }
        return "http://localhost:11434"
    }

    // MARK: - Ollama Support

    private func sendOllamaRequest(
        _ request: AIRequest,
        streamHandler: ((String) -> Void)?,
        completion: @escaping (Result<AIResponse, AIClientError>) -> Void
    ) {
        let baseUrl = getOllamaUrl()
        guard let url = URL(string: "\(baseUrl)/api/chat") else {
            completion(.failure(.invalidURL))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": request.model,
            "messages": request.messages.map { ["role": $0.role, "content": $0.content] },
            "stream": request.stream,
            "options": [
                "temperature": request.temperature ?? 0.7
            ]
        ]

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.decodingError(error)))
            return
        }

        if request.stream {
            handleOllamaStreamingRequest(urlRequest, streamHandler: streamHandler, completion: completion)
        } else {
            handleOllamaNonStreamingRequest(urlRequest, completion: completion)
        }
    }

    private func handleOllamaNonStreamingRequest(
        _ request: URLRequest,
        completion: @escaping (Result<AIResponse, AIClientError>) -> Void
    ) {
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error as NSError? {
                if error.code == NSURLErrorCannotConnectToHost || error.code == NSURLErrorTimedOut {
                    completion(.failure(.ollamaNotRunning))
                } else {
                    completion(.failure(.networkError(error)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                completion(.failure(.httpError(statusCode: httpResponse.statusCode, message: errorMessage)))
                return
            }

            do {
                let result = try self.parseOllamaResponse(data)
                completion(.success(result))
            } catch let error as AIClientError {
                completion(.failure(error))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }

        task.resume()
    }

    private func handleOllamaStreamingRequest(
        _ request: URLRequest,
        streamHandler: ((String) -> Void)?,
        completion: @escaping (Result<AIResponse, AIClientError>) -> Void
    ) {
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error as NSError? {
                if error.code == NSURLErrorCannotConnectToHost || error.code == NSURLErrorTimedOut {
                    completion(.failure(.ollamaNotRunning))
                } else {
                    completion(.failure(.networkError(error)))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                completion(.failure(.httpError(statusCode: httpResponse.statusCode, message: errorMessage)))
                return
            }

            guard let text = String(data: data, encoding: .utf8) else {
                completion(.failure(.invalidResponse))
                return
            }

            var fullContent = ""
            let lines = text.components(separatedBy: "\n")

            for line in lines {
                guard !line.isEmpty else { continue }
                guard let jsonData = line.data(using: .utf8) else { continue }

                do {
                    if let chunk = try self.parseOllamaStreamChunk(jsonData) {
                        fullContent += chunk
                        streamHandler?(chunk)
                    }
                } catch {
                    continue
                }
            }

            let response = AIResponse(content: fullContent, finishReason: "stop", usage: nil)
            completion(.success(response))
        }

        task.resume()
    }

    private func parseOllamaResponse(_ data: Data) throws -> AIResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIClientError.invalidResponse
        }

        return AIResponse(content: content, finishReason: "stop", usage: nil)
    }

    private func parseOllamaStreamChunk(_ data: Data) throws -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
        }
        return content
    }
}
