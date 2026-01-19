const std = @import("std");
const Agent = @import("Agent.zig");
const Config = @import("../config.zig").Config;
const Surface = @import("../Surface.zig");
const terminal = @import("../terminal/main.zig");
const AIBlock = terminal.AIBlock;

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

/// Get current cursor row Y position
export fn ghostty_agent_get_cursor_row(surface_ptr: *anyopaque) c_int {
    const surface: *Surface = @ptrCast(@alignCast(surface_ptr));
    surface.renderer_state.mutex.lock();
    defer surface.renderer_state.mutex.unlock();
    return @intCast(surface.io.terminal.screens.active.*.cursor.y);
}

/// Mark a specific row as AI block border
/// row_y: absolute row position
/// block_id: block ID to assign
/// is_top: true for top border, false for bottom border
export fn ghostty_agent_mark_row(
    surface_ptr: *anyopaque,
    row_y: c_int,
    block_id: u16,
    is_top: bool,
) void {
    const surface: *Surface = @ptrCast(@alignCast(surface_ptr));
    
    surface.renderer_state.mutex.lock();
    defer surface.renderer_state.mutex.unlock();
    
    const screen = surface.io.terminal.screens.active;
    
    // Find the row at this Y position
    const target_y: usize = @intCast(row_y);
    if (target_y != screen.*.cursor.y) {
        std.debug.print("⚠️  Warning: marking row {} but cursor is at {}\n", .{target_y, screen.*.cursor.y});
    }
    
    // Mark the current cursor row (should be at target_y)
    screen.*.cursor.page_row.*.ai_block_id = block_id;
    screen.*.cursor.page_row.*.ai_block_part = if (is_top) .top_border else .bottom_border;
    screen.*.cursor.page_row.*.dirty = true;
    screen.*.cursor.page_pin.node.data.dirty = true;
    
    std.debug.print("✅ Marked row {} as {s} border for block {}\n", .{
        row_y,
        if (is_top) "TOP" else "BOTTOM",
        block_id,
    });
}

/// Start an AI block (returns block ID, or 0 on failure)
/// mode: 0=agent, 1=ask, 2=plan
export fn ghostty_agent_start_block(
    surface_ptr: *anyopaque,
    mode: c_int,
) u16 {
    const surface: *Surface = @ptrCast(@alignCast(surface_ptr));
    
    const ai_mode: AIBlock.AIBlock.Mode = switch (mode) {
        0 => .agent,
        1 => .ask,
        2 => .plan,
        else => return 0,
    };
    
    // Lock terminal state
    surface.renderer_state.mutex.lock();
    defer surface.renderer_state.mutex.unlock();
    
    // Get current row
    const screen = surface.io.terminal.screens.active;
    const row_y = screen.*.cursor.y;
    
    // Create block
    const block_id = screen.*.ai_blocks.createBlock(ai_mode, row_y) catch return 0;
    
    std.debug.print("✅ Created block {} at row {} with mode {}\n", .{ block_id, row_y, @intFromEnum(ai_mode) });
    
    return block_id;
}

/// End an AI block
export fn ghostty_agent_end_block(
    surface_ptr: *anyopaque,
    block_id: u16,
) void {
    const surface: *Surface = @ptrCast(@alignCast(surface_ptr));
    
    // Lock terminal state
    surface.renderer_state.mutex.lock();
    defer surface.renderer_state.mutex.unlock();
    
    // Get current row
    const screen = surface.io.terminal.screens.active;
    const row_y = screen.*.cursor.y;
    
    // End block
    screen.*.ai_blocks.endBlock(block_id, row_y);
    
    // Mark current row as bottom border and set dirty
    screen.*.cursor.page_row.*.ai_block_id = block_id;
    screen.*.cursor.page_row.*.ai_block_part = .bottom_border;
    screen.*.cursor.page_row.*.dirty = true;
    screen.*.cursor.page_pin.node.data.dirty = true;
    
    std.debug.print("✅ C API: Ended block {} at row {}\n", .{ block_id, row_y });
    std.debug.print("   Row metadata: id={}, part={}\n", .{ screen.*.cursor.page_row.*.ai_block_id, screen.*.cursor.page_row.*.ai_block_part });
}
