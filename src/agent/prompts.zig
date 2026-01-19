const std = @import("std");
const Config = @import("../config.zig").Config;

/// Generate system prompt based on agent mode
pub fn getSystemPrompt(mode: Config.AgentMode, allocator: std.mem.Allocator) ![]const u8 {
    return switch (mode) {
        .agent => try allocator.dupe(u8,
            \\You are an autonomous terminal agent assistant. You can:
            \\- Analyze terminal output and errors
            \\- Execute commands to solve problems
            \\- Perform multi-step operations
            \\- Ask for approval before potentially destructive actions
            \\
            \\When you need to execute a command, use this format:
            \\```execute
            \\command here
            \\```
            \\
            \\You can execute multiple commands if needed. Be concise but thorough.
            \\Explain your reasoning before executing commands.
        ),
        
        .ask => try allocator.dupe(u8,
            \\You are a helpful terminal assistant. You can:
            \\- Answer questions about commands and errors
            \\- Explain terminal output
            \\- Provide documentation and examples
            \\- Suggest commands (but never execute them)
            \\
            \\You CANNOT execute commands. Only provide information and guidance.
            \\Be clear and concise. Use code blocks for examples.
        ),
        
        .plan => try allocator.dupe(u8,
            \\You are a strategic planning assistant. You can:
            \\- Break down complex tasks into steps
            \\- Create detailed implementation plans
            \\- Suggest multiple approaches with tradeoffs
            \\- Provide commands to execute (but don't run them)
            \\
            \\Create structured plans with:
            \\1. Overview and goal
            \\2. Prerequisites and requirements
            \\3. Step-by-step implementation
            \\4. Verification steps
            \\5. Potential issues and solutions
            \\
            \\Format commands as:
            \\```bash
            \\command here
            \\```
            \\
            \\Be thorough and consider edge cases.
        ),
    };
}

/// Parse commands from agent response
/// Looks for ```execute blocks and extracts commands
pub fn parseExecuteCommands(allocator: std.mem.Allocator, content: []const u8) ![][]const u8 {
    var commands = std.ArrayList([]const u8){};
    errdefer {
        for (commands.items) |cmd| allocator.free(cmd);
        commands.deinit(allocator);
    }
    
    var iter = std.mem.splitSequence(u8, content, "```execute");
    _ = iter.next(); // Skip first part
    
    while (iter.next()) |block| {
        const end = std.mem.indexOf(u8, block, "```") orelse continue;
        const command = std.mem.trim(u8, block[0..end], " \n\r\t");
        if (command.len > 0) {
            try commands.append(allocator, try allocator.dupe(u8, command));
        }
    }
    
    return commands.toOwnedSlice(allocator);
}

/// Parse bash commands from plan response
/// Looks for ```bash blocks
pub fn parseBashCommands(allocator: std.mem.Allocator, content: []const u8) ![][]const u8 {
    var commands = std.ArrayList([]const u8){};
    errdefer {
        for (commands.items) |cmd| allocator.free(cmd);
        commands.deinit(allocator);
    }
    
    var iter = std.mem.splitSequence(u8, content, "```bash");
    _ = iter.next(); // Skip first part
    
    while (iter.next()) |block| {
        const end = std.mem.indexOf(u8, block, "```") orelse continue;
        const command = std.mem.trim(u8, block[0..end], " \n\r\t");
        if (command.len > 0) {
            try commands.append(allocator, try allocator.dupe(u8, command));
        }
    }
    
    return commands.toOwnedSlice(allocator);
}
