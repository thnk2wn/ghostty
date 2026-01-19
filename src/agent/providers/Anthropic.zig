const std = @import("std");
const Provider = @import("Provider.zig").Provider;
const Allocator = std.mem.Allocator;

const Anthropic = @This();

allocator: Allocator,
api_key: []const u8,
base_url: []const u8,
default_model: []const u8,

pub fn init(allocator: Allocator, api_key: []const u8) !*Anthropic {
    const self = try allocator.create(Anthropic);
    self.* = .{
        .allocator = allocator,
        .api_key = try allocator.dupe(u8, api_key),
        .base_url = "https://api.anthropic.com/v1",
        .default_model = "claude-3-5-sonnet-latest",
    };
    return self;
}

pub fn deinit(self: *Anthropic) void {
    self.allocator.free(self.api_key);
    self.allocator.destroy(self);
}

pub fn asProvider(self: *Anthropic) Provider {
    return .{
        .ptr = self,
        .vtable = &.{
            .generate = generate,
            .generateStream = generateStream,
            .deinit = deinitProvider,
        },
    };
}

fn generate(
    ptr: *anyopaque,
    allocator: Allocator,
    request: Provider.GenerateRequest,
) Provider.GenerateError!Provider.Response {
    const self: *Anthropic = @ptrCast(@alignCast(ptr));
    
    // TODO: Implement actual HTTP request to Anthropic API
    _ = self;
    
    const content = std.fmt.allocPrint(
        allocator,
        "Anthropic stub response for: {s}\n\nThe HTTP client needs to be properly implemented for Zig 0.15.2 API.",
        .{request.prompt},
    ) catch return Provider.GenerateError.OutOfMemory;
    
    return .{
        .content = content,
        .model = try allocator.dupe(u8, request.model orelse "claude-3-5-sonnet-latest"),
        .usage = .{
            .prompt_tokens = 0,
            .completion_tokens = 0,
            .total_tokens = 0,
        },
    };
}

fn generateStream(
    ptr: *anyopaque,
    allocator: Allocator,
    request: Provider.GenerateRequest,
    callback: Provider.StreamCallback,
    userdata: ?*anyopaque,
) Provider.GenerateError!void {
    _ = ptr;
    _ = allocator;
    _ = request;
    _ = callback;
    _ = userdata;
    return Provider.GenerateError.ServerError;
}

fn deinitProvider(ptr: *anyopaque) void {
    const self: *Anthropic = @ptrCast(@alignCast(ptr));
    self.deinit();
}
