# Ghostty AI Agent

The Ghostty AI Agent provides three modes of AI-powered assistance directly in your terminal:

- **Agent Mode**: Autonomous assistant that can execute commands
- **Ask Mode**: Q&A assistant that provides information and suggestions
- **Plan Mode**: Creates detailed, structured plans for complex tasks

## Setup

### API Keys

The agent requires API keys for OpenAI or Anthropic models. Set these as environment variables:

```bash
# For OpenAI models (gpt-4o, gpt-4o-mini, etc.)
export OPENAI_API_KEY="your-openai-api-key"

# For Anthropic models (claude-3-5-sonnet-latest, etc.)
export ANTHROPIC_API_KEY="your-anthropic-api-key"
```

Add these to your shell profile (`~/.zshrc`, `~/.bashrc`, etc.) to persist across sessions.

### Enabling the Agent

Add to your Geofftty config file (`~/.config/geofftty/config`):

```
ai-agent-enabled = true
```

The agent pane will appear at the bottom of your terminal.

## Modes

### 🎨 Agent Mode

**Use when**: You want the AI to execute commands and make changes.

**Capabilities**:
- Analyzes terminal state and command history
- Executes shell commands to complete tasks
- Reads and modifies files
- Debugs issues and fixes errors
- Installs dependencies
- Provides explanations alongside actions

**Safety**:
- Commands are extracted from the AI response and require approval
- You'll see an approval dialog before any commands execute
- The agent won't run destructive commands without warning

**Example prompts**:
- "Install the Python dependencies"
- "Fix the linter errors in my code"
- "Set up a new React project with TypeScript"
- "Find and fix the bug causing the test to fail"

### ❓ Ask Mode

**Use when**: You have questions but don't want the AI to execute anything.

**Capabilities**:
- Answers questions about code, commands, and concepts
- Explains error messages and suggests fixes
- Provides code examples
- Reviews code and suggests improvements
- Teaches concepts and best practices

**Safety**:
- Read-only mode - never executes commands
- Suggests commands for you to run manually

**Example prompts**:
- "Why is my Python script failing?"
- "How do I use git rebase?"
- "Explain this error message"
- "What's the difference between npm and yarn?"

### 📋 Plan Mode

**Use when**: You need to plan complex tasks before executing.

**Capabilities**:
- Creates detailed, step-by-step plans
- Identifies prerequisites and dependencies
- Suggests best practices
- Considers edge cases and potential issues
- Provides exact commands (but doesn't execute them)

**Safety**:
- Planning-only mode - never executes anything
- Helps you understand the full scope before starting

**Example prompts**:
- "I want to add authentication to my web app"
- "Plan how to migrate from JavaScript to TypeScript"
- "How should I refactor this monolithic app into microservices?"
- "Create a deployment strategy for production"

## Model Selection

The agent supports multiple AI models:

**OpenAI Models**:
- `gpt-4o` - Most capable, best for complex tasks
- `gpt-4o-mini` - Fast and cost-effective (recommended)
- `o1-preview` - Advanced reasoning
- `o1-mini` - Fast reasoning

**Anthropic Models**:
- `claude-3-5-sonnet-latest` - Excellent for code (recommended)
- `claude-3-opus-latest` - Most capable Claude model

Use the model dropdown in the agent pane to switch between models.

## Terminal Context

The agent automatically receives context about your terminal:

- **Current directory**: Working directory
- **Shell**: Current shell (zsh, bash, etc.)
- **Recent commands**: Last 5 commands with exit codes
- **Visible output**: Recent terminal output

This context helps the agent provide relevant, situational assistance.

## Command Execution Flow (Agent Mode Only)

1. **Submit query**: Type your request and press Enter
2. **AI processes**: The agent analyzes your request and generates a response
3. **Command extraction**: Any bash/shell code blocks are extracted as commands
4. **Approval dialog**: If commands are found, you'll see an approval dialog
5. **Execute or reject**: Choose to run the commands or reject them
6. **Output display**: Command results appear in the terminal

## Tips

### Getting the Best Results

1. **Be specific**: "Install Express.js and set up a basic server" is better than "set up backend"
2. **Provide context**: Mention relevant details like "using Python 3.11" or "on macOS"
3. **Use the right mode**: 
   - Learning? Use **Ask**
   - Planning big change? Use **Plan**
   - Ready to execute? Use **Agent**
4. **Iterate**: If the first response isn't perfect, ask follow-up questions

### Keyboard Shortcuts

- **Focus input**: The agent pane input is auto-focused
- **Submit**: Press `Enter` to submit
- **Clear blocks**: Click the ✖️ button to clear output history

### Cost Management

- Use `gpt-4o-mini` or `claude-3-5-sonnet-latest` for most tasks
- Reserve `gpt-4o` or `claude-3-opus-latest` for complex problems
- Ask mode typically uses fewer tokens than Agent mode

## Architecture

The implementation consists of:

- **`AgentBridge.swift`**: Bridge between UI and AI backend
- **`AIClient.swift`**: Handles API calls to OpenAI/Anthropic
- **`AIPrompts.swift`**: System prompts for each mode
- **`AgentPaneView.swift`**: UI components
- **`AgentPaneViewModel.swift`**: State management

### Terminal Integration

The agent uses Ghostty's native terminal rendering with special "AI blocks":

- AI responses appear as styled blocks in the terminal
- Blocks scroll with terminal content
- Visual indicators show mode (✨ Agent, ❓ Ask, 📋 Plan)
- Blocks persist in terminal history

## Troubleshooting

### "Missing API key" error

**Solution**: Set the appropriate environment variable and restart Ghostty.

```bash
export OPENAI_API_KEY="your-key"
# or
export ANTHROPIC_API_KEY="your-key"
```

### Agent pane not showing

**Solution**: Check your config file has `ai-agent-enabled = true` and restart.

### Commands not executing

**Possible causes**:
1. You're in Ask or Plan mode (use Agent mode)
2. Commands weren't extracted (ensure they're in bash code blocks)
3. Command approval was rejected

### Slow responses

**Possible causes**:
1. Using a slower model (try `gpt-4o-mini`)
2. Network latency
3. Long context (terminal output is truncated to 2000 chars)

## Privacy & Security

- **API calls**: Your queries and terminal context are sent to the selected AI provider
- **No telemetry**: Ghostty doesn't track your usage
- **Local execution**: Commands run locally on your machine
- **Approval required**: All commands in Agent mode require your approval
- **No automatic execution**: The AI can't run commands without explicit approval

## Future Enhancements

Planned features:
- [ ] Multi-turn conversations with context
- [ ] File operations (read, edit, create)
- [ ] Git integration
- [ ] Custom system prompts
- [ ] Local model support (Ollama, LM Studio)
- [ ] Command history and undo
- [ ] RAG over project files
