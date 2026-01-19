const std = @import("std");

/// State for the agent pane UI
pub const PaneState = struct {
    allocator: std.mem.Allocator,
    messages: std.ArrayList(Message),
    current_input: []const u8,
    is_processing: bool,
    focused: bool,
    
    pub const Message = struct {
        id: u64,
        role: Role,
        content: []const u8,
        reasoning: ?[]const u8,
        commands: ?[][]const u8,
        timestamp: i64,
        
        pub const Role = enum {
            user,
            assistant,
            system,
        };
        
        pub fn deinit(self: *Message, allocator: std.mem.Allocator) void {
            allocator.free(self.content);
            if (self.reasoning) |r| allocator.free(r);
            if (self.commands) |cmds| {
                for (cmds) |cmd| allocator.free(cmd);
                allocator.free(cmds);
            }
        }
    };
    
    pub fn init(allocator: std.mem.Allocator) PaneState {
        return .{
            .allocator = allocator,
            .messages = std.ArrayList(Message){},
            .current_input = &.{},
            .is_processing = false,
            .focused = false,
        };
    }
    
    pub fn deinit(self: *PaneState) void {
        for (self.messages.items) |*msg| {
            msg.deinit(self.allocator);
        }
        self.messages.deinit(self.allocator);
        
        if (self.current_input.len > 0) {
            self.allocator.free(self.current_input);
        }
    }
    
    pub fn addMessage(
        self: *PaneState,
        role: Message.Role,
        content: []const u8,
        reasoning: ?[]const u8,
        commands: ?[][]const u8,
    ) !void {
        const msg = Message{
            .id = @intCast(self.messages.items.len),
            .role = role,
            .content = try self.allocator.dupe(u8, content),
            .reasoning = if (reasoning) |r| try self.allocator.dupe(u8, r) else null,
            .commands = if (commands) |cmds| blk: {
                const owned = try self.allocator.alloc([]const u8, cmds.len);
                for (cmds, 0..) |cmd, i| {
                    owned[i] = try self.allocator.dupe(u8, cmd);
                }
                break :blk owned;
            } else null,
            .timestamp = std.time.timestamp(),
        };
        
        try self.messages.append(self.allocator, msg);
    }
    
    pub fn setInput(self: *PaneState, input: []const u8) !void {
        if (self.current_input.len > 0) {
            self.allocator.free(self.current_input);
        }
        self.current_input = try self.allocator.dupe(u8, input);
    }
    
    pub fn clearInput(self: *PaneState) void {
        if (self.current_input.len > 0) {
            self.allocator.free(self.current_input);
            self.current_input = &.{};
        }
    }
};
