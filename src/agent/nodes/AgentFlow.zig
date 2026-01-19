const std = @import("std");
const Provider = @import("../providers/Provider.zig").Provider;
const config_mod = @import("../config.zig");
const prompts = @import("../prompts.zig");
const Allocator = std.mem.Allocator;

/// Agent mode flow - can execute commands
pub const AgentFlowNode = struct {
    provider: Provider,
    config: config_mod.AgentConfig,
    
    pub fn init(provider: Provider, cfg: config_mod.AgentConfig) AgentFlowNode {
        return .{
            .provider = provider,
            .config = cfg,
        };
    }
    
    pub fn execute(
        self: *AgentFlowNode,
        allocator: Allocator,
        prompt: []const u8,
    ) !AgentResponse {
        const system_prompt = try prompts.getSystemPrompt(.agent, allocator);
        defer allocator.free(system_prompt);
        
        const response = try self.provider.generate(allocator, .{
            .prompt = prompt,
            .system_prompt = system_prompt,
            .max_tokens = self.config.max_tokens,
            .temperature = self.config.temperature,
            .model = self.config.model,
            .mode = .agent,
        });
        
        // Parse commands from response
        const commands = try prompts.parseExecuteCommands(allocator, response.content);
        
        return .{
            .response = response,
            .commands = commands,
            .needs_approval = commands.len > 0 and self.config.require_approval,
        };
    }
    
    pub const AgentResponse = struct {
        response: Provider.Response,
        commands: [][]const u8,
        needs_approval: bool,
        
        pub fn deinit(self: *AgentResponse, allocator: Allocator) void {
            self.response.deinit(allocator);
            for (self.commands) |cmd| {
                allocator.free(cmd);
            }
            allocator.free(self.commands);
        }
    };
};
