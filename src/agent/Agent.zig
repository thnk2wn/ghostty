const std = @import("std");
const Agent = @This();

const Config = @import("../config.zig").Config;
const Provider = @import("providers/Provider.zig").Provider;
const OpenAI = @import("providers/OpenAI.zig");
const Anthropic = @import("providers/Anthropic.zig");
const Ollama = @import("providers/Ollama.zig");
const config_mod = @import("config.zig");
const approval_mod = @import("approval.zig");
const pane_mod = @import("pane.zig");
const AgentFlowNode = @import("nodes/AgentFlow.zig").AgentFlowNode;
const AskFlowNode = @import("nodes/AskFlow.zig").AskFlowNode;
const PlanFlowNode = @import("nodes/PlanFlow.zig").PlanFlowNode;
const CommandDetectorNode = @import("nodes/CommandDetector.zig").CommandDetectorNode;

const Allocator = std.mem.Allocator;

allocator: Allocator,
config: config_mod.AgentConfig,
provider: Provider,
provider_impl: ProviderImpl,
approval_store: approval_mod.ApprovalStore,
pane_state: pane_mod.PaneState,

/// Union to hold the actual provider implementation
const ProviderImpl = union(enum) {
    openai: *OpenAI,
    anthropic: *Anthropic,
    ollama: *Ollama,
    
    pub fn deinit(self: ProviderImpl) void {
        switch (self) {
            .openai => |p| p.deinit(),
            .anthropic => |p| p.deinit(),
            .ollama => |p| p.deinit(),
        }
    }
};

pub fn init(allocator: Allocator, cfg: *const Config, workspace_dir: ?[]const u8) !*Agent {
    const agent_config = config_mod.AgentConfig.fromConfig(cfg);
    
    // Initialize provider based on config
    const api_key = try agent_config.getApiKey(allocator);
    defer if (api_key) |k| allocator.free(k);
    
    const provider_impl = if (std.mem.eql(u8, agent_config.provider, "openai")) blk: {
        const key = api_key orelse return error.MissingApiKey;
        const openai = try OpenAI.init(allocator, key);
        break :blk ProviderImpl{ .openai = openai };
    } else if (std.mem.eql(u8, agent_config.provider, "anthropic")) blk: {
        const key = api_key orelse return error.MissingApiKey;
        const anthropic = try Anthropic.init(allocator, key);
        break :blk ProviderImpl{ .anthropic = anthropic };
    } else if (std.mem.eql(u8, agent_config.provider, "ollama")) blk: {
        const ollama = try Ollama.init(allocator, agent_config.ollama_url);
        break :blk ProviderImpl{ .ollama = ollama };
    } else {
        return error.InvalidProvider;
    };
    
    const provider = switch (provider_impl) {
        .openai => |p| p.asProvider(),
        .anthropic => |p| p.asProvider(),
        .ollama => |p| p.asProvider(),
    };
    
    const self = try allocator.create(Agent);
    self.* = .{
        .allocator = allocator,
        .config = agent_config,
        .provider = provider,
        .provider_impl = provider_impl,
        .approval_store = try approval_mod.ApprovalStore.init(
            allocator,
            agent_config.approval_scope,
            workspace_dir,
        ),
        .pane_state = pane_mod.PaneState.init(allocator),
    };
    
    // Load approval history
    try self.approval_store.load();
    
    return self;
}

pub fn deinit(self: *Agent) void {
    self.approval_store.save() catch {};
    self.approval_store.deinit();
    self.pane_state.deinit();
    self.provider_impl.deinit();
    self.allocator.destroy(self);
}

/// Process user input through the agent
pub fn processInput(self: *Agent, input: []const u8) !void {
    // Add user message to pane
    try self.pane_state.addMessage(.user, input, null, null);
    self.pane_state.is_processing = true;
    
    errdefer self.pane_state.is_processing = false;
    
    // Route based on mode
    const response = switch (self.config.mode) {
        .agent => try self.executeAgentMode(input),
        .ask => try self.executeAskMode(input),
        .plan => try self.executePlanMode(input),
    };
    
    self.pane_state.is_processing = false;
    _ = response;
}

fn executeAgentMode(self: *Agent, input: []const u8) !void {
    var node = AgentFlowNode.init(self.provider, self.config);
    
    var result = try node.execute(self.allocator, input);
    defer result.deinit(self.allocator);
    
    // Add assistant response to pane
    try self.pane_state.addMessage(
        .assistant,
        result.response.content,
        null,
        result.commands,
    );
    
    // If commands need approval, they'll be handled by the UI
    if (result.needs_approval) {
        // UI will show approval dialog
        return;
    }
    
    // If no approval needed and we have commands, execute them
    if (result.commands.len > 0) {
        // TODO: Execute commands
    }
}

fn executeAskMode(self: *Agent, input: []const u8) !void {
    var node = AskFlowNode.init(self.provider, self.config);
    
    const response = try node.execute(self.allocator, input);
    defer response.deinit(self.allocator);
    
    // Add assistant response to pane
    try self.pane_state.addMessage(
        .assistant,
        response.content,
        null,
        null,
    );
}

fn executePlanMode(self: *Agent, input: []const u8) !void {
    var node = PlanFlowNode.init(self.provider, self.config);
    
    var result = try node.execute(self.allocator, input);
    defer result.deinit(self.allocator);
    
    // Add assistant response to pane
    try self.pane_state.addMessage(
        .assistant,
        result.response.content,
        null,
        result.suggested_commands,
    );
}

/// Check if command execution is approved
pub fn isCommandApproved(self: *Agent, command: []const u8) bool {
    return self.approval_store.isApproved(command);
}

/// Set approval for a command
pub fn setCommandApproval(self: *Agent, command: []const u8, approved: bool) !void {
    try self.approval_store.setApproval(command, approved);
}

/// Change the agent mode at runtime
pub fn setMode(self: *Agent, mode: Config.AgentMode) !void {
    if (!self.config.allow_mode_switch) {
        return error.ModeSwitchNotAllowed;
    }
    self.config.mode = mode;
}

pub const Error = error{
    MissingApiKey,
    InvalidProvider,
    ModeSwitchNotAllowed,
    OutOfMemory,
};
