# Building Ghostty with AI Agent on macOS

## Prerequisites

### 1. Install Xcode

Ghostty requires **full Xcode** (not just Command Line Tools) to build the macOS app.

**For main branch development:**
- Requires Xcode 26 and macOS 26 SDK
- You don't need macOS 26 to build - Xcode 26 works on macOS 15

```bash
# Check current Xcode path
xcode-select -p

# If it shows Command Line Tools, install full Xcode from App Store
# Then select it:
sudo xcode-select --switch /Applications/Xcode.app

# Verify
xcode-select -p
# Should show: /Applications/Xcode.app/Contents/Developer
```

### 2. Verify Dependencies

```bash
# Check Zig version (should be 0.15.2+)
zig version

# Check macOS SDK
xcrun --show-sdk-path
# Should show: /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
```

## Build Steps

### Step 1: Clean Build Cache (if needed)

```bash
cd /Users/jobotgeoff/repos/ghostty
rm -rf .zig-cache zig-out
```

### Step 2: Build Ghostty

```bash
# Build in debug mode (default)
zig build

# Or build in release mode
zig build -Doptimize=ReleaseFast
```

### Step 3: Run Ghostty

```bash
# Run the app
zig build run

# Or open the built app
open zig-out/bin/Ghostty.app
```

## Current Status

✅ **All AI agent code is implemented:**
- ✅ PocketFlow-Zig dependency added (hash fixed)
- ✅ Configuration system complete
- ✅ Three LLM providers (OpenAI, Anthropic, Ollama)
- ✅ Three AI modes (Agent, Ask, Plan)
- ✅ macOS SwiftUI UI complete
- ✅ Surface integration hooks added

⚠️ **Build Status:**
- Hash: Fixed ✅
- Xcode: Needs full Xcode installation
- SDK: Needs proper SDK configuration

## Testing Without Full Build

If you can't install Xcode 26 immediately, you can:

1. **Test Zig code compilation only:**
   ```bash
   zig build test
   ```

2. **Build specific components:**
   ```bash
   # Test agent module compiles
   zig build-lib src/agent.zig -femit-bin=zig-out/libagent.a
   ```

3. **Use an existing Ghostty build:**
   - If you have a working Ghostty build from a stable release
   - Copy your new agent files into that build
   - Rebuild just the changed parts

## Configuration for Testing

Once built, create `~/.config/ghostty/config`:

```ini
# Enable AI agent (minimal config)
ai-agent-enabled = true
ai-agent-provider = openai
ai-agent-mode = ask

# Or use Ollama (no API key needed)
ai-agent-enabled = true
ai-agent-provider = ollama
ai-agent-ollama-url = http://localhost:11434
ai-agent-model = llama3
```

Set API key via environment:
```bash
export OPENAI_API_KEY="sk-..."
zig build run
```

## Troubleshooting

### Error: DarwinSdkNotFound

**Problem:** Using Command Line Tools instead of full Xcode

**Solution:**
1. Install Xcode from Mac App Store
2. Run: `sudo xcode-select --switch /Applications/Xcode.app`
3. Open Xcode once to accept license
4. Verify: `xcrun --show-sdk-path`

### Error: Wrong Xcode Version

**Problem:** Main branch requires Xcode 26

**Solution:**
1. Download Xcode 26 beta from developer.apple.com
2. Install it
3. Select it: `sudo xcode-select --switch /Applications/Xcode-beta.app`

### Error: PocketFlow-Zig Hash Mismatch

**Problem:** Hash doesn't match

**Solution:** Already fixed! Hash is now:
```
pocketflow-0.2.0-DMo6y3IWAQDBvqw0OtesASCks-2LD-KOeZgI36913USh
```

### Compilation Errors in Agent Code

If you get Zig compilation errors in the agent module:

1. Check error message location
2. Common fixes:
   - Missing imports
   - Type mismatches
   - Allocator issues

Report errors and we can fix them!

## Alternative: Use Stable Release Branch

If Xcode 26 is not available, you could:

1. Switch to a stable branch that works with your Xcode version
2. Cherry-pick the agent commits
3. Build on that branch

```bash
# Check available branches/tags
git branch -a
git tag

# Switch to stable version
git checkout v1.3.0  # or whatever version matches your Xcode

# Cherry-pick agent commits (would need commit IDs)
```

## Next Steps After Build Succeeds

1. **Verify agent pane appears** in terminal
2. **Test configuration** is loaded correctly
3. **Test Ask mode** with a simple question
4. **Test OpenAI** or Ollama provider
5. **Test mode switching**
6. **Test approval system** (Agent mode)

See `AGENT_NEXT_STEPS.md` for comprehensive testing guide.

## Quick Start (assuming Xcode is set up)

```bash
# 1. Build
cd /Users/jobotgeoff/repos/ghostty
zig build

# 2. Configure
mkdir -p ~/.config/ghostty
cat > ~/.config/ghostty/config << 'EOF'
ai-agent-enabled = true
ai-agent-provider = openai
ai-agent-mode = ask
EOF

# 3. Set API key
export OPENAI_API_KEY="sk-..."

# 4. Run
zig build run

# 5. Use AI agent!
# The pane should appear at the bottom of your terminal
# Try asking: "What does ls -la do?"
```

## Status Check Commands

```bash
# Check if agent module compiles
zig build-lib src/agent.zig --cache-dir /tmp/zig-test

# Check configuration parsing
zig build test -Dtest-filter=agent

# Verify Swift files are found
find macos/Sources -name "*Agent*"
```

## Need Help?

1. Check Ghostty's official build docs: `HACKING.md`
2. Review agent implementation: `AGENT_IMPLEMENTATION_STATUS.md`
3. Testing guide: `AGENT_NEXT_STEPS.md`
4. Open an issue with build errors
