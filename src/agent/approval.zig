const std = @import("std");
const Config = @import("../config.zig").Config;

/// Approval decision storage
pub const ApprovalStore = struct {
    allocator: std.mem.Allocator,
    decisions: std.StringHashMap(bool),
    scope: Config.ApprovalScope,
    workspace_dir: ?[]const u8,
    
    pub fn init(
        allocator: std.mem.Allocator,
        scope: Config.ApprovalScope,
        workspace_dir: ?[]const u8,
    ) !ApprovalStore {
        return .{
            .allocator = allocator,
            .decisions = std.StringHashMap(bool).init(allocator),
            .scope = scope,
            .workspace_dir = if (workspace_dir) |dir| 
                try allocator.dupe(u8, dir) 
            else 
                null,
        };
    }
    
    pub fn deinit(self: *ApprovalStore) void {
        var it = self.decisions.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.decisions.deinit();
        
        if (self.workspace_dir) |dir| {
            self.allocator.free(dir);
        }
    }
    
    /// Check if a command has been approved
    pub fn isApproved(self: *ApprovalStore, command: []const u8) bool {
        const key = self.makeKey(command) catch return false;
        defer self.allocator.free(key);
        
        return self.decisions.get(key) orelse false;
    }
    
    /// Store an approval decision
    pub fn setApproval(self: *ApprovalStore, command: []const u8, approved: bool) !void {
        const key = try self.makeKey(command);
        
        // Remove old key if exists
        if (self.decisions.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
        }
        
        const owned_key = try self.allocator.dupe(u8, key);
        try self.decisions.put(owned_key, approved);
    }
    
    /// Make a storage key based on scope
    fn makeKey(self: *ApprovalStore, command: []const u8) ![]const u8 {
        return switch (self.scope) {
            .global => try self.allocator.dupe(u8, command),
            .workspace => if (self.workspace_dir) |dir|
                try std.fmt.allocPrint(
                    self.allocator,
                    "{s}:{s}",
                    .{ dir, command },
                )
            else
                try self.allocator.dupe(u8, command),
        };
    }
    
    /// Load approval decisions from disk
    pub fn load(self: *ApprovalStore) !void {
        // TODO: Implement persistent storage
        // Could use XDG_STATE_HOME/ghostty/agent-approvals.json
        _ = self;
    }
    
    /// Save approval decisions to disk
    pub fn save(self: *ApprovalStore) !void {
        // TODO: Implement persistent storage
        _ = self;
    }
};
