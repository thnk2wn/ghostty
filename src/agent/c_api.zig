const std = @import("std");
const Agent = @import("Agent.zig");
const Config = @import("../config.zig").Config;
const Surface = @import("../Surface.zig");

/// C API for agent integration
/// These functions are called from Swift/Objective-C

/// Initialize an agent for a surface
export fn ghostty_agent_new(
    surface_ptr: *anyopaque,
    config_ptr: *Config,
    workspace_dir: ?[*:0]const u8,
) ?*Agent {
    const allocator = std.heap.c_allocator;
    
    const dir = if (workspace_dir) |d| std.mem.span(d) else null;
    
    const agent = Agent.init(allocator, config_ptr, dir) catch {
        return null;
    };
    
    _ = surface_ptr; // TODO: Store surface reference in agent
    return agent;
}

/// Free an agent
export fn ghostty_agent_free(agent: *Agent) void {
    agent.deinit();
}

/// Process user input through the agent
/// Returns true if processing started successfully
export fn ghostty_agent_process_input(
    agent: *Agent,
    input: [*:0]const u8,
    input_len: usize,
) bool {
    const input_slice = input[0..input_len];
    
    agent.processInput(input_slice) catch {
        return false;
    };
    
    return true;
}

/// Get pending commands that need approval
/// Returns number of commands, fills command_ptrs array
export fn ghostty_agent_get_pending_commands(
    agent: *Agent,
    command_ptrs: [*]*const u8,
    max_commands: usize,
) usize {
    _ = agent;
    _ = command_ptrs;
    _ = max_commands;
    // TODO: Implement
    return 0;
}

/// Approve and execute pending commands
export fn ghostty_agent_approve_commands(agent: *Agent) void {
    _ = agent;
    // TODO: Implement command execution
}

/// Reject pending commands
export fn ghostty_agent_reject_commands(agent: *Agent) void {
    _ = agent;
    // TODO: Clear pending commands
}

/// Set agent mode
export fn ghostty_agent_set_mode(
    agent: *Agent,
    mode: c_int,
) bool {
    const agent_mode: Config.AgentMode = switch (mode) {
        0 => .agent,
        1 => .ask,
        2 => .plan,
        else => return false,
    };
    
    agent.setMode(agent_mode) catch {
        return false;
    };
    
    return true;
}

/// Check if agent is currently processing
export fn ghostty_agent_is_processing(agent: *Agent) bool {
    return agent.pane_state.is_processing;
}

/// Write output directly to the terminal (not as user input)
/// This makes the text appear in the scrollback as if it came from a program
export fn ghostty_agent_write_output(
    surface_ptr: *anyopaque,
    text: [*:0]const u8,
    text_len: usize,
) bool {
    const surface: *Surface = @ptrCast(@alignCast(surface_ptr));
    
    // Get the actual text slice
    const output = text[0..text_len];
    
    // Write to terminal output (processOutput expects data from PTY)
    surface.io.processOutput(output);
    return true;
}
