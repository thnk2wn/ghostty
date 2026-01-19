const std = @import("std");
const Config = @import("../config.zig").Config;

/// Agent-specific configuration derived from main config
pub const AgentConfig = struct {
    mode: Config.AgentMode,
    provider: []const u8,
    api_key: ?[]const u8,
    model: ?[]const u8,
    ollama_url: []const u8,
    require_approval: bool,
    approval_scope: Config.ApprovalScope,
    show_reasoning: bool,
    plan_show_details: bool,
    max_tokens: u32,
    temperature: f32,
    allow_mode_switch: bool,
    
    pub fn fromConfig(cfg: *const Config) AgentConfig {
        return .{
            .mode = cfg.@"ai-agent-mode",
            .provider = cfg.@"ai-agent-provider",
            .api_key = cfg.@"ai-agent-api-key",
            .model = cfg.@"ai-agent-model",
            .ollama_url = cfg.@"ai-agent-ollama-url",
            .require_approval = cfg.@"ai-agent-require-approval",
            .approval_scope = cfg.@"ai-agent-approval-scope",
            .show_reasoning = cfg.@"ai-agent-show-reasoning",
            .plan_show_details = cfg.@"ai-agent-plan-show-details",
            .max_tokens = cfg.@"ai-agent-max-tokens",
            .temperature = cfg.@"ai-agent-temperature",
            .allow_mode_switch = cfg.@"ai-agent-allow-mode-switch",
        };
    }
    
    /// Get API key from config or environment variable
    pub fn getApiKey(self: *const AgentConfig, allocator: std.mem.Allocator) !?[]const u8 {
        // Try environment variable first
        const env_key: ?[]const u8 = if (std.mem.eql(u8, self.provider, "openai"))
            "OPENAI_API_KEY"
        else if (std.mem.eql(u8, self.provider, "anthropic"))
            "ANTHROPIC_API_KEY"
        else
            null;
        
        if (env_key) |key| {
            if (std.process.getEnvVarOwned(allocator, key)) |env_val| {
                return env_val;
            } else |_| {}
        }
        
        // Fall back to config value
        if (self.api_key) |key| {
            return try allocator.dupe(u8, key);
        }
        
        return null;
    }
    
    /// Get the model name or provider default
    pub fn getModel(self: *const AgentConfig) []const u8 {
        if (self.model) |m| return m;
        
        // Provider defaults
        if (std.mem.eql(u8, self.provider, "openai")) {
            return "gpt-4o-mini";
        } else if (std.mem.eql(u8, self.provider, "anthropic")) {
            return "claude-3-5-sonnet-latest";
        } else if (std.mem.eql(u8, self.provider, "ollama")) {
            return "llama3";
        }
        
        return "gpt-4o-mini"; // Ultimate fallback
    }
};
