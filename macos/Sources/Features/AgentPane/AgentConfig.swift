import Foundation

struct AgentConfig {
    var defaultModel: String
    var defaultMode: AgentMode
    var streamResponses: Bool
    var temperature: Double
    var autoExecuteCommands: Bool
    var maxOutputTokens: Int
    var useRichOverlays: Bool
    var hideLayoutPicker: Bool

    static let `default` = AgentConfig(
        defaultModel: "gpt-4o-mini",
        defaultMode: .ask,
        streamResponses: true,
        temperature: 0.7,
        autoExecuteCommands: false,
        maxOutputTokens: 4096,
        useRichOverlays: true,
        hideLayoutPicker: false
    )

    static func load() -> AgentConfig {
        let defaults = UserDefaults.standard

        return AgentConfig(
            defaultModel: defaults.string(forKey: "agentDefaultModel") ?? "gpt-4o-mini",
            defaultMode: AgentMode(rawValue: defaults.string(forKey: "agentDefaultMode") ?? "Ask") ?? .ask,
            streamResponses: defaults.object(forKey: "agentStreamResponses") as? Bool ?? true,
            temperature: defaults.object(forKey: "agentTemperature") as? Double ?? 0.7,
            autoExecuteCommands: defaults.bool(forKey: "agentAutoExecuteCommands"),
            maxOutputTokens: defaults.object(forKey: "agentMaxOutputTokens") as? Int ?? 4096,
            useRichOverlays: defaults.object(forKey: "agentUseRichOverlays") as? Bool ?? true,
            hideLayoutPicker: defaults.bool(forKey: "agentHideLayoutPicker")
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(defaultModel, forKey: "agentDefaultModel")
        defaults.set(defaultMode.rawValue, forKey: "agentDefaultMode")
        defaults.set(streamResponses, forKey: "agentStreamResponses")
        defaults.set(temperature, forKey: "agentTemperature")
        defaults.set(autoExecuteCommands, forKey: "agentAutoExecuteCommands")
        defaults.set(maxOutputTokens, forKey: "agentMaxOutputTokens")
        defaults.set(useRichOverlays, forKey: "agentUseRichOverlays")
        defaults.set(hideLayoutPicker, forKey: "agentHideLayoutPicker")
    }

    static func hasValidAPIKey(for model: String) -> Bool {
        let provider = AIProvider.from(model: model)

        switch provider {
        case .openai:
            return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil
        case .anthropic:
            return ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil
        }
    }

    static func availableModels() -> [String] {
        var models: [String] = []

        if hasValidAPIKey(for: "gpt-4o") {
            models.append(contentsOf: [
                "gpt-4o",
                "gpt-4o-mini",
                "o1-preview",
                "o1-mini"
            ])
        }

        if hasValidAPIKey(for: "claude-3-5-sonnet-latest") {
            models.append(contentsOf: [
                "claude-3-5-sonnet-latest",
                "claude-3-opus-latest"
            ])
        }

        return models.isEmpty ? ["gpt-4o-mini"] : models
    }
}

extension AgentPaneViewModel {
    func loadConfig() {
        let config = AgentConfig.load()
        self.selectedModel = config.defaultModel
        self.mode = config.defaultMode
        self.useRichOverlays = config.useRichOverlays
        self.hideLayoutPicker = config.hideLayoutPicker
    }

    func saveConfig() {
        let config = AgentConfig(
            defaultModel: selectedModel,
            defaultMode: mode,
            streamResponses: true,
            temperature: 0.7,
            autoExecuteCommands: false,
            maxOutputTokens: 4096,
            useRichOverlays: useRichOverlays,
            hideLayoutPicker: hideLayoutPicker
        )
        config.save()
    }
}
