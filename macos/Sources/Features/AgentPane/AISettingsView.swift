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

            // Content - Tabbed interface
            TabView {
                ModelsTab(viewModel: viewModel)
                    .tabItem {
                        Label("Models", systemImage: "cpu")
                    }

                ProvidersTab(viewModel: viewModel)
                    .tabItem {
                        Label("Providers", systemImage: "key")
                    }
            }
            .frame(minWidth: 500, minHeight: 450)

            Divider()

            // Footer with save button
            HStack {
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
            }
            .padding()
        }
        .frame(width: 550)
        .onAppear {
            viewModel.loadSettings()
        }
    }
}

// MARK: - Models Tab

struct ModelsTab: View {
    @ObservedObject var viewModel: AISettingsViewModel

    var body: some View {
        Form {
            // Defaults Section
            Section {
                Picker("Default Mode", selection: $viewModel.defaultMode) {
                    ForEach(AgentMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                Picker("Default Reasoning", selection: $viewModel.defaultReasoningLevel) {
                    ForEach(ReasoningLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .help("Reasoning level for models that support it (e.g., GPT-5.2 codex)")
            } header: {
                Text("Defaults")
            }

            // Models by Mode Section
            Section {
                Picker("Configure models for", selection: $viewModel.selectedModeForConfig) {
                    ForEach(AgentMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)

                // Default model for this mode
                Picker("Default model", selection: Binding(
                    get: { viewModel.defaultModelForSelectedMode },
                    set: { viewModel.setDefaultModel($0, forMode: viewModel.selectedModeForConfig) }
                )) {
                    ForEach(viewModel.enabledModelsForSelectedMode, id: \.id) { model in
                        Text(model.displayName).tag(model.id)
                    }
                }
                .disabled(viewModel.enabledModelsForSelectedMode.isEmpty)
            } header: {
                Text("Models by Mode")
            }

            // Model list grouped by provider
            ForEach(viewModel.providers) { provider in
                Section {
                    ForEach(viewModel.modelsForProvider(provider.id)) { model in
                        ModelToggleRow(
                            model: model,
                            isEnabled: viewModel.isModelEnabled(model.id),
                            hasAPIKey: viewModel.hasAPIKey(for: provider.id),
                            onToggle: { viewModel.toggleModel(model.id) }
                        )
                    }
                } header: {
                    HStack {
                        Text(provider.displayName)
                        if !viewModel.hasAPIKey(for: provider.id) && provider.requiresApiKey {
                            Text("(No API key)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ModelToggleRow: View {
    let model: ModelDefinition
    let isEnabled: Bool
    let hasAPIKey: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                        if model.supportsReasoning {
                            Text("Reasoning")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(3)
                        }
                    }
                    Text(model.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(!hasAPIKey)
        }
        .opacity(hasAPIKey ? 1.0 : 0.5)
    }
}

// MARK: - Providers Tab

struct ProvidersTab: View {
    @ObservedObject var viewModel: AISettingsViewModel

    var body: some View {
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
                        SecureField("API Key", text: Binding(
                            get: { viewModel.apiKey },
                            set: { newValue in
                                viewModel.apiKey = newValue
                                // Track pending key for this provider so models become available immediately
                                viewModel.pendingApiKeys[viewModel.selectedProvider.rawValue] = newValue
                            }
                        ))
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

                    Button("Delete Key", role: .destructive) {
                        viewModel.deleteKey()
                    }
                    .disabled(!viewModel.hasKeychainKey)
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
        }
        .formStyle(.grouped)
    }
}

// MARK: - View Model

class AISettingsViewModel: ObservableObject {
    // Provider/Auth state
    @Published var selectedProvider: AIProvider = .openai
    @Published var apiKey: String = ""
    @Published var ollamaUrl: String = "http://localhost:11434"
    @Published var isTesting: Bool = false
    @Published var connectionStatus: ConnectionStatus?
    @Published var hasKeychainKey: Bool = false

    // Track pending (unsaved) API keys per provider
    @Published var pendingApiKeys: [String: String] = [:]

    // Model configuration state
    @Published var defaultMode: AgentMode = .ask
    @Published var defaultReasoningLevel: ReasoningLevel = .none
    @Published var selectedModeForConfig: AgentMode = .ask
    @Published var enabledModelsByMode: [String: Set<String>] = [:]
    @Published var defaultModelByMode: [String: String] = [:]

    struct ConnectionStatus {
        let isSuccess: Bool
        let message: String
    }

    var providers: [ProviderDefinition] {
        ModelRegistry.shared.providers
    }

    func modelsForProvider(_ providerId: String) -> [ModelDefinition] {
        ModelRegistry.shared.allModels.filter { $0.provider == providerId }
    }

    var enabledModelsForSelectedMode: [ModelDefinition] {
        let enabledIds = enabledModelsByMode[selectedModeForConfig.rawValue] ?? []
        return ModelRegistry.shared.allModels.filter { enabledIds.contains($0.id) && hasAPIKey(for: $0.provider) }
    }

    var defaultModelForSelectedMode: String {
        defaultModelByMode[selectedModeForConfig.rawValue] ?? ""
    }

    func setDefaultModel(_ modelId: String, forMode mode: AgentMode) {
        defaultModelByMode[mode.rawValue] = modelId
    }

    func isModelEnabled(_ modelId: String) -> Bool {
        enabledModelsByMode[selectedModeForConfig.rawValue]?.contains(modelId) ?? false
    }

    func toggleModel(_ modelId: String) {
        let mode = selectedModeForConfig.rawValue
        if enabledModelsByMode[mode] == nil {
            enabledModelsByMode[mode] = []
        }

        if enabledModelsByMode[mode]!.contains(modelId) {
            enabledModelsByMode[mode]!.remove(modelId)
            // If we removed the default model, pick a new one
            if defaultModelByMode[mode] == modelId {
                defaultModelByMode[mode] = enabledModelsByMode[mode]!.first ?? ""
            }
        } else {
            enabledModelsByMode[mode]!.insert(modelId)
            // If no default is set, use this one
            if defaultModelByMode[mode]?.isEmpty ?? true {
                defaultModelByMode[mode] = modelId
            }
        }
    }

    /// Check if a provider has a valid API key (either saved or pending in this session)
    func hasAPIKey(for providerId: String) -> Bool {
        // Ollama doesn't need an API key
        if providerId == "ollama" {
            return true
        }
        // Check pending (unsaved) key first
        if let pending = pendingApiKeys[providerId], !pending.isEmpty {
            return true
        }
        // Fall back to saved key check
        return AgentConfig.hasValidAPIKey(for: providerId)
    }

    func loadSettings() {
        let registry = ModelRegistry.shared

        // Load model configuration from registry
        enabledModelsByMode = registry.enabledModelsByMode.mapValues { Set($0) }
        defaultModelByMode = registry.defaultModelByMode
        defaultReasoningLevel = registry.defaultReasoningLevel

        // Load default mode from config
        if let modeStr = ConfigFileWriter.readValue(key: "ai-agent-mode"),
           let mode = AgentMode(rawValue: modeStr.capitalized) {
            defaultMode = mode
        }

        // Load provider key
        loadKeyForProvider()
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
        // Save all pending API keys (not just the currently selected provider)
        for (providerId, key) in pendingApiKeys {
            if !key.isEmpty {
                do {
                    try KeychainHelper.save(key: key, account: providerId)
                    AgentConfig.markProviderConfigured(providerId)
                } catch {
                    print("Failed to save API key to Keychain for \(providerId): \(error)")
                }
            }
        }

        // Also save current provider's key if it was modified
        if selectedProvider.requiresApiKey && !apiKey.isEmpty {
            do {
                try KeychainHelper.save(key: apiKey, account: selectedProvider.keychainAccount)
                hasKeychainKey = true
                AgentConfig.markProviderConfigured(selectedProvider.rawValue)
            } catch {
                print("Failed to save API key to Keychain: \(error)")
            }
        }

        // Save Ollama URL if configured
        if !ollamaUrl.isEmpty {
            ConfigFileWriter.updateValues(["ai-agent-ollama-url": ollamaUrl])
        }

        // Update ModelRegistry with new settings
        let registry = ModelRegistry.shared
        registry.enabledModelsByMode = enabledModelsByMode.mapValues { Set($0) }
        registry.defaultModelByMode = defaultModelByMode
        registry.defaultReasoningLevel = defaultReasoningLevel

        // Save to config file via registry
        registry.saveUserConfig()

        // Save default mode
        ConfigFileWriter.updateValues(["ai-agent-mode": defaultMode.rawValue.lowercased()])

        // Mark setup as completed
        AgentConfig.markSetupCompleted()

        // Post notification
        NotificationCenter.default.post(name: .aiSettingsDidChange, object: nil)
    }

    func deleteKey() {
        do {
            try KeychainHelper.delete(account: selectedProvider.keychainAccount)
            apiKey = ""
            hasKeychainKey = false
            connectionStatus = nil
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
}

// MARK: - Notification

extension Notification.Name {
    static let aiSettingsDidChange = Notification.Name("aiSettingsDidChange")
}

#Preview {
    AISettingsView()
}
