const std = @import("std");
const Allocator = std.mem.Allocator;
const Config = @import("../../config.zig").Config;

/// Abstract LLM provider interface
pub const Provider = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        generate: *const fn (
            ptr: *anyopaque,
            allocator: Allocator,
            request: GenerateRequest,
        ) GenerateError!Response,
        
        generateStream: *const fn (
            ptr: *anyopaque,
            allocator: Allocator,
            request: GenerateRequest,
            callback: StreamCallback,
            userdata: ?*anyopaque,
        ) GenerateError!void,
        
        deinit: *const fn (ptr: *anyopaque) void,
    };
    
    pub const GenerateRequest = struct {
        prompt: []const u8,
        system_prompt: ?[]const u8 = null,
        max_tokens: u32 = 2048,
        temperature: f32 = 0.7,
        model: ?[]const u8 = null,
        mode: Config.AgentMode = .ask,
    };
    
    pub const Response = struct {
        content: []const u8,
        model: []const u8,
        usage: Usage,
        
        pub const Usage = struct {
            prompt_tokens: u32,
            completion_tokens: u32,
            total_tokens: u32,
        };
        
        pub fn deinit(self: Response, allocator: Allocator) void {
            allocator.free(self.content);
            allocator.free(self.model);
        }
    };
    
    pub const StreamChunk = struct {
        content: []const u8,
        is_final: bool,
    };
    
    pub const StreamCallback = *const fn (chunk: StreamChunk, userdata: ?*anyopaque) void;
    
    pub const GenerateError = error{
        NetworkError,
        InvalidApiKey,
        RateLimitExceeded,
        InvalidModel,
        ContextLengthExceeded,
        OutOfMemory,
        InvalidRequest,
        ServerError,
    };
    
    pub fn generate(
        self: Provider,
        allocator: Allocator,
        request: GenerateRequest,
    ) GenerateError!Response {
        return self.vtable.generate(self.ptr, allocator, request);
    }
    
    pub fn generateStream(
        self: Provider,
        allocator: Allocator,
        request: GenerateRequest,
        callback: StreamCallback,
        userdata: ?*anyopaque,
    ) GenerateError!void {
        return self.vtable.generateStream(self.ptr, allocator, request, callback, userdata);
    }
    
    pub fn deinit(self: Provider) void {
        self.vtable.deinit(self.ptr);
    }
};
