const std = @import("std");
const Provider = @import("../providers/Provider.zig").Provider;
const config_mod = @import("../config.zig");
const prompts = @import("../prompts.zig");
const Allocator = std.mem.Allocator;

/// Plan mode flow - creates plans without execution
pub const PlanFlowNode = struct {
    provider: Provider,
    config: config_mod.AgentConfig,
    
    pub fn init(provider: Provider, cfg: config_mod.AgentConfig) PlanFlowNode {
        return .{
            .provider = provider,
            .config = cfg,
        };
    }
    
    pub fn execute(
        self: *PlanFlowNode,
        allocator: Allocator,
        task: []const u8,
    ) !PlanResponse {
        const system_prompt = try prompts.getSystemPrompt(.plan, allocator);
        defer allocator.free(system_prompt);
        
        const response = try self.provider.generate(allocator, .{
            .prompt = task,
            .system_prompt = system_prompt,
            .max_tokens = if (self.config.plan_show_details) 4096 else 2048,
            .temperature = 0.8, // Slightly higher for creative planning
            .model = self.config.model,
            .mode = .plan,
        });
        
        // Parse suggested commands from plan
        const commands = try prompts.parseBashCommands(allocator, response.content);
        
        return .{
            .response = response,
            .suggested_commands = commands,
        };
    }
    
    pub const PlanResponse = struct {
        response: Provider.Response,
        suggested_commands: [][]const u8,
        
        pub fn deinit(self: *PlanResponse, allocator: Allocator) void {
            self.response.deinit(allocator);
            for (self.suggested_commands) |cmd| {
                allocator.free(cmd);
            }
            allocator.free(self.suggested_commands);
        }
    };
};
