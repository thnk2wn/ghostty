const std = @import("std");
const Config = @import("../../config.zig").Config;

/// Routes to appropriate flow based on agent mode
pub const ModeRouterNode = struct {
    mode: Config.AgentMode,
    
    pub fn init(mode: Config.AgentMode) ModeRouterNode {
        return .{ .mode = mode };
    }
    
    pub fn route(self: *const ModeRouterNode) []const u8 {
        return switch (self.mode) {
            .agent => "agent_flow",
            .ask => "ask_flow",
            .plan => "plan_flow",
        };
    }
};
