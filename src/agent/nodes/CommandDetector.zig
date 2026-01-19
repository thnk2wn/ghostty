const std = @import("std");

/// Detects whether input looks like a shell command or AI prompt
pub const CommandDetectorNode = struct {
    pub fn detect(input: []const u8) bool {
        const trimmed = std.mem.trim(u8, input, " \t\n\r");
        
        if (trimmed.len == 0) return false;
        
        // Heuristics for command detection
        const is_command = 
            // Common command prefixes
            std.mem.startsWith(u8, trimmed, "cd ") or
            std.mem.startsWith(u8, trimmed, "ls ") or
            std.mem.startsWith(u8, trimmed, "git ") or
            std.mem.startsWith(u8, trimmed, "npm ") or
            std.mem.startsWith(u8, trimmed, "cargo ") or
            std.mem.startsWith(u8, trimmed, "docker ") or
            std.mem.startsWith(u8, trimmed, "kubectl ") or
            std.mem.startsWith(u8, trimmed, "python ") or
            std.mem.startsWith(u8, trimmed, "node ") or
            std.mem.startsWith(u8, trimmed, "zig ") or
            // Relative or absolute path execution
            std.mem.startsWith(u8, trimmed, "./") or
            std.mem.startsWith(u8, trimmed, "/") or
            // Shell operators
            std.mem.indexOf(u8, trimmed, " | ") != null or
            std.mem.indexOf(u8, trimmed, " && ") != null or
            std.mem.indexOf(u8, trimmed, " || ") != null or
            std.mem.indexOf(u8, trimmed, " > ") != null or
            std.mem.indexOf(u8, trimmed, " < ") != null;
        
        return is_command;
    }
};
