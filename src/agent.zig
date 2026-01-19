//! AI Agent module for Ghostty
//! 
//! This module provides AI-powered terminal assistance with three modes:
//! - Agent: Autonomous assistant that can execute commands (with approval)
//! - Ask: Q&A assistant without command execution
//! - Plan: Creates detailed plans without executing
//!
//! Supports multiple LLM providers:
//! - OpenAI (GPT-4, GPT-5.2, etc.)
//! - Anthropic (Claude models)
//! - Ollama (local models)

const std = @import("std");

// Core agent functionality
pub const Agent = @import("agent/Agent.zig");
pub const Pane = @import("agent/pane.zig");
pub const config = @import("agent/config.zig");
pub const approval = @import("agent/approval.zig");
pub const prompts = @import("agent/prompts.zig");

// LLM providers
pub const providers = struct {
    pub const Provider = @import("agent/providers/Provider.zig");
    pub const OpenAI = @import("agent/providers/OpenAI.zig");
    pub const Anthropic = @import("agent/providers/Anthropic.zig");
    pub const Ollama = @import("agent/providers/Ollama.zig");
};

// PocketFlow nodes
pub const nodes = struct {
    pub const ModeRouter = @import("agent/nodes/ModeRouter.zig");
    pub const CommandDetector = @import("agent/nodes/CommandDetector.zig");
    pub const AgentFlow = @import("agent/nodes/AgentFlow.zig");
    pub const AskFlow = @import("agent/nodes/AskFlow.zig");
    pub const PlanFlow = @import("agent/nodes/PlanFlow.zig");
};

// C API for Swift/Objective-C integration
pub const c_api = @import("agent/c_api.zig");

test {
    std.testing.refAllDecls(@This());
}
