# AI Agent Usage Examples

This guide provides practical examples for using each agent mode effectively.

## Agent Mode Examples

### Development Tasks

**Setting up a new project:**
```
Create a new Python web app with FastAPI, including a virtual environment and basic project structure
```

**Installing dependencies:**
```
Install all the dependencies from package.json
```

**Fixing errors:**
```
The tests are failing. Find out why and fix them.
```

**Code generation:**
```
Add a new API endpoint to create users with email validation
```

### DevOps & System Admin

**Docker operations:**
```
Build and run the Docker container for this project
```

**Git operations:**
```
Create a new feature branch and commit my changes
```

**Environment setup:**
```
Set up the development environment for this Node.js project
```

**Log analysis:**
```
Check the application logs for errors in the last hour
```

### Debugging

**Error investigation:**
```
I'm getting a 500 error. Check the logs and find the root cause.
```

**Performance issues:**
```
The app is slow. Profile it and identify bottlenecks.
```

**Dependency issues:**
```
There's a version conflict with the dependencies. Resolve it.
```

## Ask Mode Examples

### Learning & Explanation

**Concept explanation:**
```
What's the difference between async/await and promises in JavaScript?
```

**Error understanding:**
```
I'm seeing "EADDRINUSE" error. What does this mean and how do I fix it?
```

**Best practices:**
```
What's the recommended way to structure a React application?
```

**Command explanation:**
```
Explain what this regex does: ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$
```

### Code Review & Advice

**Architecture advice:**
```
Should I use microservices or a monolith for my e-commerce app?
```

**Security review:**
```
Is this password hashing implementation secure?
```

**Performance tips:**
```
How can I optimize this SQL query that's taking too long?
```

**Tool comparison:**
```
What are the pros and cons of PostgreSQL vs MongoDB for my use case?
```

### Troubleshooting (without execution)

**Diagnostic guidance:**
```
My Docker container keeps crashing. What should I check?
```

**Configuration help:**
```
How do I configure nginx as a reverse proxy for my Node app?
```

**Debugging strategies:**
```
What's the best way to debug memory leaks in a Python application?
```

## Plan Mode Examples

### Large Projects

**Full application development:**
```
Plan how to build a task management app with user authentication, real-time updates, and mobile support
```

**Migration projects:**
```
Create a plan to migrate our monolithic Rails app to microservices
```

**Infrastructure setup:**
```
Plan the complete AWS infrastructure for a high-traffic web application with auto-scaling
```

### Architecture & Design

**System design:**
```
Design a URL shortener service that can handle 1 million requests per day
```

**API design:**
```
Plan a RESTful API for a social media platform with posts, comments, and likes
```

**Database design:**
```
Design the database schema for an e-learning platform with courses, students, and progress tracking
```

### Feature Development

**Complex features:**
```
Plan how to add real-time chat functionality to our existing web app
```

**Integration planning:**
```
Create a plan to integrate Stripe payments into our subscription service
```

**Testing strategy:**
```
Design a comprehensive testing strategy for our React application
```

### Refactoring & Optimization

**Code refactoring:**
```
Plan how to refactor this legacy codebase to use modern React hooks
```

**Performance optimization:**
```
Create a plan to optimize our slow-loading dashboard page
```

**Technical debt:**
```
Plan how to address the technical debt in our authentication system
```

## Multi-Mode Workflows

Some tasks work best by using multiple modes in sequence:

### Workflow 1: Learn → Plan → Execute

1. **Ask**: "What's the best way to set up CI/CD for a Python project?"
2. **Plan**: "Create a detailed plan for setting up GitHub Actions CI/CD for my Python FastAPI project"
3. **Agent**: "Implement the CI/CD plan you just created"

### Workflow 2: Explore → Plan → Validate

1. **Ask**: "What are the different approaches to adding caching to my API?"
2. **Plan**: "Plan how to implement Redis caching for the most expensive endpoints"
3. **Ask**: "Review this plan and identify potential issues"

### Workflow 3: Debug → Plan → Fix

1. **Ask**: "Analyze this error and explain what's happening"
2. **Plan**: "Create a step-by-step plan to fix this issue"
3. **Agent**: "Execute the fix according to the plan"

## Pro Tips

### Making Effective Queries

**Be specific about context:**
- ✅ "Add error handling to the user registration endpoint in routes/auth.js"
- ❌ "Add error handling"

**Include relevant details:**
- ✅ "Set up Jest testing for React 18 with TypeScript and ES modules"
- ❌ "Set up testing"

**State your constraints:**
- ✅ "Create a REST API using only built-in Node.js modules (no frameworks)"
- ❌ "Create a REST API"

### Getting Better Results

**For Agent Mode:**
- Start with clear, actionable requests
- Break complex tasks into smaller requests
- Review commands before approving

**For Ask Mode:**
- Include error messages or code snippets
- Mention your experience level
- Ask follow-up questions for clarification

**For Plan Mode:**
- Describe the end goal clearly
- Mention technical constraints (budget, timeline, team size)
- Ask about alternatives and trade-offs

### Common Patterns

**Iterative development:**
```
Agent: "Create a basic Express server"
Agent: "Add authentication with JWT"
Agent: "Add input validation with Joi"
```

**Progressive learning:**
```
Ask: "What is Docker?"
Ask: "How do Docker volumes work?"
Plan: "Plan how to containerize my Node.js app"
Agent: "Implement the containerization plan"
```

**Validation cycle:**
```
Agent: "Run the test suite"
Ask: "Explain why test X is failing"
Agent: "Fix the failing test based on your explanation"
```

## Limitations & Best Practices

### What the Agent CAN Do
- Execute commands with your approval
- Read terminal output and history
- Install packages and dependencies
- Create and modify files
- Debug common issues
- Run tests and checks

### What the Agent CANNOT Do
- Read or modify files outside terminal commands (yet)
- Access your browser or desktop apps
- Make external API calls directly (only through commands)
- Remember context across sessions (currently)

### Safety Guidelines
- **Review commands** before approving, especially:
  - File deletions (`rm`, `del`)
  - System changes (`sudo`, `chmod`)
  - Database modifications
  - Production deployments
- **Test in safe environments** first
- **Backup important data** before major operations
- **Use Plan mode** for complex or risky changes

### Performance Tips
- Use `gpt-4o-mini` for routine tasks (faster, cheaper)
- Reserve `gpt-4o` or `claude-3-5-sonnet-latest` for complex problems
- Clear output blocks periodically to reduce clutter
- Break very large tasks into smaller requests
