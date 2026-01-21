import SwiftUI

/// View for configuring AI provider settings (API keys, models, etc.)
struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AISettingsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Content
            Form {
                Section {
                    Picker("Provider", selection: $viewModel.selectedProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .onChange(of: viewModel.selectedProvider) { _ in
                        viewModel.loadKeyForProvider()
                    }
                }

                Section {
                    if viewModel.selectedProvider.requiresApiKey {
                        HStack {
                            SecureField("API Key", text: $viewModel.apiKey)
                                .textFieldStyle(.roundedBorder)

                            Button(action: viewModel.testConnection) {
                                if viewModel.isTesting {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 50)
                                } else {
                                    Text("Test")
                                        .frame(width: 50)
                                }
                            }
                            .disabled(viewModel.apiKey.isEmpty || viewModel.isTesting)
                        }

                        if viewModel.hasKeychainKey {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Stored in Keychain")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let status = viewModel.connectionStatus {
                            HStack(spacing: 4) {
                                Image(systemName: status.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(status.isSuccess ? .green : .red)
                                    .font(.caption)
                                Text(status.message)
                                    .font(.caption)
                                    .foregroundColor(status.isSuccess ? .green : .red)
                            }
                        }
                    } else {
                        Text("No API key required for \(viewModel.selectedProvider.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Authentication")
                }

                if viewModel.selectedProvider == .ollama {
                    Section {
                        TextField("Base URL", text: $viewModel.ollamaUrl)
                            .textFieldStyle(.roundedBorder)
                        Text("Default: http://localhost:11434")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Ollama Server")
                    }
                }

                Section {
                    Picker("Model", selection: $viewModel.selectedModel) {
                        ForEach(viewModel.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }

                    if viewModel.selectedProvider == .ollama {
                        TextField("Custom model name", text: $viewModel.customModelName)
                            .textFieldStyle(.roundedBorder)
                        Text("Enter the name of any model you've pulled with `ollama pull`")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Model")
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 400, minHeight: 350)

            Divider()

            // Footer with save button
            HStack {
                Button("Delete Key", role: .destructive) {
                    viewModel.deleteKey()
                }
                .disabled(!viewModel.hasKeychainKey)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    viewModel.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedProvider.requiresApiKey && viewModel.apiKey.isEmpty)
            }
            .padding()
        }
        .frame(width: 450)
        .onAppear {
            viewModel.loadKeyForProvider()
        }
    }
}

// MARK: - View Model

class AISettingsViewModel: ObservableObject {
    @Published var selectedProvider: AIProvider = .openai
    @Published var apiKey: String = ""
    @Published var ollamaUrl: String = "http://localhost:11434"
    @Published var selectedModel: String = "gpt-4o"
    @Published var customModelName: String = ""
    @Published var isTesting: Bool = false
    @Published var connectionStatus: ConnectionStatus?
    @Published var hasKeychainKey: Bool = false

    struct ConnectionStatus {
        let isSuccess: Bool
        let message: String
    }

    var availableModels: [String] {
        selectedProvider.defaultModels
    }

    func loadKeyForProvider() {
        if let key = KeychainHelper.load(account: selectedProvider.keychainAccount) {
            apiKey = key
            hasKeychainKey = true
        } else {
            apiKey = ""
            hasKeychainKey = false
        }
        connectionStatus = nil

        // Set default model for provider
        if let firstModel = selectedProvider.defaultModels.first {
            selectedModel = firstModel
        }
    }

    func testConnection() {
        guard !apiKey.isEmpty else { return }
        isTesting = true
        connectionStatus = nil

        Task {
            let success = await performConnectionTest()
            await MainActor.run {
                isTesting = false
                connectionStatus = ConnectionStatus(
                    isSuccess: success,
                    message: success ? "Connection successful" : "Connection failed"
                )
            }
        }
    }

    private func performConnectionTest() async -> Bool {
        switch selectedProvider {
        case .openai:
            return await testOpenAIConnection()
        case .anthropic:
            return await testAnthropicConnection()
        case .ollama:
            return await testOllamaConnection()
        }
    }

    private func testOpenAIConnection() async -> Bool {
        guard let url = URL(string: "https://api.openai.com/v1/models") else { return false }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func testAnthropicConnection() async -> Bool {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            return statusCode == 200 || statusCode == 400
        } catch {
            return false
        }
    }

    private func testOllamaConnection() async -> Bool {
        let baseUrl = ollamaUrl.isEmpty ? "http://localhost:11434" : ollamaUrl
        guard let url = URL(string: "\(baseUrl)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func save() {
        if selectedProvider.requiresApiKey && !apiKey.isEmpty {
            do {
                try KeychainHelper.save(key: apiKey, account: selectedProvider.keychainAccount)
                hasKeychainKey = true
                // Mark provider as configured so we don't need to check keychain again
                AgentConfig.markProviderConfigured(selectedProvider.rawValue)
            } catch {
                print("Failed to save API key to Keychain: \(error)")
            }
        }

        // Save model and other settings to config file
        let model = customModelName.isEmpty ? selectedModel : customModelName
        ConfigFileWriter.updateValues([
            "ai-agent-provider": selectedProvider.rawValue,
            "ai-agent-model": model
        ])

        if selectedProvider == .ollama && !ollamaUrl.isEmpty {
            ConfigFileWriter.updateValues(["ai-agent-ollama-url": ollamaUrl])
        }

        // Mark setup as completed so banner doesn't show anymore
        AgentConfig.markSetupCompleted()

        // Post notification that settings changed
        NotificationCenter.default.post(name: .aiSettingsDidChange, object: nil)
    }

    func deleteKey() {
        do {
            try KeychainHelper.delete(account: selectedProvider.keychainAccount)
            apiKey = ""
            hasKeychainKey = false
            connectionStatus = nil
            // Clear the configured cache
            AgentConfig.markProviderUnconfigured(selectedProvider.rawValue)
        } catch {
            print("Failed to delete API key from Keychain: \(error)")
        }
    }
}

// MARK: - AI Provider Enum

enum AIProvider: String, CaseIterable, Identifiable {
    case openai
    case anthropic
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .ollama: return "Ollama"
        }
    }

    var keychainAccount: String {
        rawValue
    }

    var requiresApiKey: Bool {
        switch self {
        case .openai, .anthropic: return true
        case .ollama: return false
        }
    }

    var defaultModels: [String] {
        switch self {
        case .openai:
            return ["gpt-4o", "gpt-4o-mini", "o1-preview", "o1-mini"]
        case .anthropic:
            return ["claude-3-5-sonnet-latest", "claude-3-opus-latest", "claude-3-haiku-latest"]
        case .ollama:
            return ["llama3", "codellama", "mistral", "mixtral"]
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let aiSettingsDidChange = Notification.Name("aiSettingsDidChange")
}

#Preview {
    AISettingsView()
}
