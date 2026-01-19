const std = @import("std");
const Provider = @import("Provider.zig").Provider;
const Allocator = std.mem.Allocator;

const Ollama = @This();

allocator: Allocator,
base_url: []const u8,
default_model: []const u8,

pub fn init(allocator: Allocator, base_url: []const u8) !*Ollama {
    const self = try allocator.create(Ollama);
    self.* = .{
        .allocator = allocator,
        .base_url = try allocator.dupe(u8, base_url),
        .default_model = "llama3",
    };
    return self;
}

pub fn deinit(self: *Ollama) void {
    self.allocator.free(self.base_url);
    self.allocator.destroy(self);
}

pub fn asProvider(self: *Ollama) Provider {
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
    const self: *Ollama = @ptrCast(@alignCast(ptr));
    
    // TODO: Implement actual HTTP request to Ollama API
    _ = self;
    
    const content = std.fmt.allocPrint(
        allocator,
        "Ollama stub response for: {s}\n\nThe HTTP client needs to be properly implemented for Zig 0.15.2 API.",
        .{request.prompt},
    ) catch return Provider.GenerateError.OutOfMemory;
    
    return .{
        .content = content,
        .model = try allocator.dupe(u8, request.model orelse "llama3"),
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
    const self: *Ollama = @ptrCast(@alignCast(ptr));
    self.deinit();
}
