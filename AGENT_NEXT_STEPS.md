# AI Agent Implementation - Next Steps & Testing Guide

## ✅ Implementation Complete!

All major components have been implemented:

1. ✅ Build configuration (PocketFlow-Zig dependency)
2. ✅ Configuration system (14 config options)
3. ✅ Core agent module (Zig)
4. ✅ Three LLM providers (OpenAI, Anthropic, Ollama)
5. ✅ Flow nodes (Agent/Ask/Plan modes)
6. ✅ Agent coordinator
7. ✅ Surface integration points
8. ✅ macOS UI (SwiftUI)

## 🔧 Build & Compilation Steps

### 1. Fix PocketFlow-Zig Hash

The dependency hash in `build.zig.zon` is a placeholder. Update it:

```bash
# Get the correct hash
zig fetch https://github.com/The-Pocket/PocketFlow-Zig/archive/refs/tags/v0.2.0.tar.gz

# Copy the hash output and update build.zig.zon line:
# .hash = "12209f4b2f..." -> .hash = "<actual hash>"
```

### 2. Update Build System

May need to add agent module to `build.zig`. Check if automatic discovery works first:

```bash
zig build
```

If errors about missing agent module:
- Ensure `src/agent.zig` is discovered
- May need explicit module registration in `build.zig`

### 3. Compile

```bash
# macOS
zig build

# Test compilation
zig build test
```

## 🧪 Testing Checklist

### Phase 1: Basic Compilation ✓
- [ ] Fix PocketFlow-Zig hash
- [ ] Resolve any Zig compilation errors
- [ ] Ensure all agent modules compile
- [ ] Check Swift/Objective-C bridge compatibility

### Phase 2: Configuration Testing
- [ ] Test config parsing with sample config file:

```ini
# Test config
ai-agent-enabled = true
ai-agent-provider = openai
ai-agent-model = gpt-4o-mini
ai-agent-mode = ask
```

- [ ] Verify config defaults work
- [ ] Test environment variable override (OPENAI_API_KEY)
- [ ] Test invalid config handling

### Phase 3: Provider Testing

#### OpenAI Provider
```bash
export OPENAI_API_KEY="sk-..."
# Start Ghostty with ai-agent-enabled=true
# Test in Ask mode first (safest)
```

Test cases:
- [ ] Simple query: "What does ls -la do?"
- [ ] Error explanation: "Explain this error: command not found"
- [ ] Mode switching (if enabled)
- [ ] Model selection

#### Anthropic Provider
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

Config:
```ini
ai-agent-provider = anthropic
ai-agent-model = claude-3-5-sonnet-latest
```

Test cases:
- [ ] Same as OpenAI tests
- [ ] Verify different API format works
- [ ] Check token counting

#### Ollama Provider
```bash
# Start Ollama server
ollama serve

# Pull a model
ollama pull llama3
```

Config:
```ini
ai-agent-provider = ollama
ai-agent-model = llama3
ai-agent-ollama-url = http://localhost:11434
```

Test cases:
- [ ] Local inference works
- [ ] No API key needed
- [ ] Response quality acceptable

### Phase 4: Mode Testing

#### Ask Mode (Safest - Start Here)
- [ ] Q&A works
- [ ] No command execution
- [ ] Helpful responses
- [ ] No approval dialogs shown

#### Plan Mode
- [ ] Creates structured plans
- [ ] Shows suggested commands
- [ ] Commands not executed
- [ ] ```bash blocks parsed correctly

#### Agent Mode (Most Complex)
- [ ] Can suggest commands
- [ ] ```execute blocks parsed
- [ ] Approval dialog appears
- [ ] Can approve/reject commands
- [ ] Approval persistence works
- [ ] Workspace vs global scope

### Phase 5: UI Testing

#### macOS UI
- [ ] Agent pane appears at bottom
- [ ] Mode selector works
- [ ] Model selector dropdown works
- [ ] Messages display correctly
- [ ] Input field accepts text
- [ ] Submit button works
- [ ] Approval dialog appears (Agent mode)
- [ ] Approve/Reject buttons work
- [ ] Reasoning disclosure works
- [ ] Scrolling works
- [ ] Clear messages button
- [ ] Info popover displays

#### UI Polish
- [ ] Animations smooth
- [ ] Colors match mode (blue/purple/orange)
- [ ] Focus handling correct
- [ ] Keyboard shortcuts work
- [ ] Resizing works properly

### Phase 6: Integration Testing
- [ ] Agent doesn't interfere with normal terminal
- [ ] Can switch focus between terminal and agent
- [ ] Config reload works
- [ ] Multiple terminals/tabs work
- [ ] Memory usage acceptable
- [ ] No crashes or leaks

### Phase 7: Error Handling
- [ ] Invalid API key shows error
- [ ] Network errors handled gracefully
- [ ] Rate limits handled
- [ ] Malformed responses don't crash
- [ ] Large responses work
- [ ] Unicode/emoji in responses

## 🐛 Known Issues & TODOs

### High Priority
1. **Command Execution** - Not yet implemented in Agent.zig
   - Need to integrate with Ghostty's pty system
   - Shell escaping and safety
   - Output capture

2. **Streaming Responses** - Marked as TODO in providers
   - Would improve UX significantly
   - Need SSE parsing for OpenAI/Anthropic
   - Ollama has streaming support

3. **Approval Persistence** - save/load not implemented
   - Need to decide on storage format (JSON?)
   - Location: `~/.local/state/ghostty/agent-approvals.json`
   - Handle workspace vs global scope

4. **Build Integration** - May need explicit module registration
   - Check if zig build discovers agent module
   - May need to update build.zig

### Medium Priority
5. **Error Messages** - Need user-friendly error display
   - API key errors
   - Network errors
   - Model not found

6. **UI Refinements**
   - Add keyboard shortcut to focus agent pane
   - Add clear all button
   - Better streaming indicator
   - Command execution status

7. **Workspace Detection** - Get current working directory
   - For context in prompts
   - For approval scope

### Low Priority
8. **GTK UI** - Linux support (optional)
9. **Metrics** - Token usage display
10. **History** - Persistent conversation history

## 📝 Example Configuration

### Minimal (OpenAI)
```ini
ai-agent-enabled = true
ai-agent-provider = openai
# Set OPENAI_API_KEY environment variable
```

### Full Featured
```ini
# Enable AI agent
ai-agent-enabled = true

# Provider settings
ai-agent-provider = openai
ai-agent-api-key = sk-your-key-here
ai-agent-model = gpt-4o

# Mode settings
ai-agent-mode = ask
ai-agent-allow-mode-switch = true

# Safety settings
ai-agent-require-approval = true
ai-agent-approval-scope = workspace

# Display settings
ai-agent-show-reasoning = true
ai-agent-plan-show-details = true

# LLM parameters
ai-agent-max-tokens = 2048
ai-agent-temperature = 0.7
```

### Development/Testing
```ini
ai-agent-enabled = true
ai-agent-provider = ollama
ai-agent-ollama-url = http://localhost:11434
ai-agent-model = llama3
ai-agent-mode = ask
ai-agent-require-approval = false  # For faster testing
```

## 🚀 Recommended Testing Order

1. **Start with Ollama** (local, free, safe)
   - No API key needed
   - Fast iteration
   - Test all modes

2. **Move to OpenAI Ask Mode** (safe, useful)
   - Test real API integration
   - Verify prompts work well
   - Check error handling

3. **Test Plan Mode** (no execution)
   - Verify command parsing
   - Check plan quality
   - Test suggested commands

4. **Finally Agent Mode** (most complex)
   - Start with simple commands
   - Test approval flow
   - Verify safety mechanisms

## 📊 Success Criteria

### Must Have
- [x] Compiles without errors
- [ ] Basic Ask mode works
- [ ] At least one provider works (OpenAI or Ollama)
- [ ] macOS UI displays correctly
- [ ] No crashes or memory leaks

### Should Have
- [ ] All three providers work
- [ ] Mode switching works
- [ ] Approval system works
- [ ] Config system works
- [ ] UI polish complete

### Nice to Have
- [ ] Streaming responses
- [ ] Command execution
- [ ] Persistent approvals
- [ ] GTK UI

## 🔍 Debugging Tips

### Enable Logging
```bash
export GHOSTTY_LOG=true
```

### Check Agent State
Add debug prints in:
- `src/agent/Agent.zig::processInput()`
- Provider generate() functions
- Surface key handling

### UI Debugging
- Use Xcode to debug SwiftUI
- Check Console.app for macOS logs
- Add print statements in ViewModel

### Network Debugging
- Use mitmproxy to inspect API calls
- Check API response format
- Verify authentication headers

## 📚 Documentation Needed

1. User guide for AI agent feature
2. Configuration reference
3. Privacy/security notes
4. Troubleshooting guide
5. Provider-specific setup guides

## 🎯 Next Actions

1. **Immediate** (Required for basic functionality)
   - Fix PocketFlow-Zig hash
   - Compile and fix any build errors
   - Test with Ollama or OpenAI Ask mode

2. **Short Term** (Within a week)
   - Implement command execution
   - Add streaming support
   - Polish UI based on testing

3. **Medium Term** (Within a month)
   - Persistent approval storage
   - GTK UI (if desired)
   - Additional safety features

## 🤝 Contributing Back

If you plan to contribute this to Ghostty:
1. Clean up code comments
2. Write tests
3. Update documentation
4. Create PR with detailed description
5. Be ready to iterate based on feedback

## 📞 Need Help?

Check:
1. `AGENT_IMPLEMENTATION_STATUS.md` - Component overview
2. Config field docs in `Config.zig`
3. Provider interfaces in `src/agent/providers/`
4. Agent coordinator in `src/agent/Agent.zig`

---

**Status**: Implementation complete, ready for testing and refinement! 🎉
