const std = @import("std");
const Provider = @import("../providers/Provider.zig").Provider;
const config_mod = @import("../config.zig");
const prompts = @import("../prompts.zig");
const Allocator = std.mem.Allocator;

/// Ask mode flow - Q&A only, no execution
pub const AskFlowNode = struct {
    provider: Provider,
    config: config_mod.AgentConfig,
    
    pub fn init(provider: Provider, cfg: config_mod.AgentConfig) AskFlowNode {
        return .{
            .provider = provider,
            .config = cfg,
        };
    }
    
    pub fn execute(
        self: *AskFlowNode,
        allocator: Allocator,
        prompt: []const u8,
    ) !Provider.Response {
        const system_prompt = try prompts.getSystemPrompt(.ask, allocator);
        defer allocator.free(system_prompt);
        
        return try self.provider.generate(allocator, .{
            .prompt = prompt,
            .system_prompt = system_prompt,
            .max_tokens = self.config.max_tokens,
            .temperature = self.config.temperature,
            .model = self.config.model,
            .mode = .ask,
        });
    }
};
