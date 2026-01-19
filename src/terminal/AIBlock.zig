//! AI Block tracking for terminal
//! Tracks AI response blocks that can be rendered with custom styling

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const AIBlock = struct {
    id: u16,
    mode: Mode,
    start_row: usize,
    end_row: usize,
    collapsed: bool = false,

    pub const Mode = enum(u8) {
        agent = 0,
        ask = 1,
        plan = 2,
    };
};

pub const AIBlockStorage = struct {
    blocks: std.ArrayList(AIBlock),
    next_id: u16 = 1,
    allocator: Allocator,

    pub fn init(allocator: Allocator) AIBlockStorage {
        return .{
            .blocks = std.ArrayList(AIBlock){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AIBlockStorage) void {
        self.blocks.deinit(self.allocator);
    }

    pub fn createBlock(self: *AIBlockStorage, mode: AIBlock.Mode, start_row: usize) !u16 {
        const id = self.next_id;
        self.next_id += 1;

        try self.blocks.append(self.allocator, .{
            .id = id,
            .mode = mode,
            .start_row = start_row,
            .end_row = start_row, // Will be updated when block ends
            .collapsed = false,
        });

        return id;
    }

    pub fn endBlock(self: *AIBlockStorage, id: u16, end_row: usize) void {
        for (self.blocks.items) |*block| {
            if (block.id == id) {
                block.end_row = end_row;
                return;
            }
        }
    }

    pub fn getBlock(self: *const AIBlockStorage, id: u16) ?*const AIBlock {
        for (self.blocks.items) |*block| {
            if (block.id == id) {
                return block;
            }
        }
        return null;
    }

    pub fn toggleCollapsed(self: *AIBlockStorage, id: u16) void {
        for (self.blocks.items) |*block| {
            if (block.id == id) {
                block.collapsed = !block.collapsed;
                return;
            }
        }
    }
};
