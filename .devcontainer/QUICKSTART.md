# Devcontainer Quick Start Guide

This is a condensed guide to get you up and running quickly with the Auto-Claude devcontainer.

## 1. Open in Container

### VSCode Remote Containers
1. Install Docker Desktop
2. Install "Remote - Containers" extension
3. Open project folder in VSCode
4. Press `F1` → `Remote-Containers: Reopen in Container`
5. Wait 5-10 minutes for initial setup

### GitHub Codespaces
1. Go to repository on GitHub
2. Click `Code` → `Codespaces` → `Create codespace on develop`
3. Wait 5-10 minutes for initial setup

## 2. Verify Setup

Run the verification script:

```bash
bash .devcontainer/verify-setup.sh
```

All checks should pass (✓ marks). If any fail (✗ marks), see troubleshooting below.

## 3. Configure Environment

### Backend API Keys

Edit `apps/backend/.env`:

```bash
# Required: Claude Code OAuth token
# Authenticate first with: claude (then type /login)
CLAUDE_CODE_OAUTH_TOKEN=your-token

# Required: Graphiti memory provider (choose one)
GRAPHITI_ENABLED=true
OPENAI_API_KEY=sk-...          # For OpenAI
# OR
ANTHROPIC_API_KEY=sk-ant-...   # For Anthropic
VOYAGE_API_KEY=pa-...          # (use with Anthropic)
```

### Authenticate Claude CLI

```bash
claude
# Type: /login
# Complete OAuth in browser
```

## 4. Test Installation

```bash
# Test backend
cd apps/backend
python run.py --list

# Test frontend
cd ../..
npm run dev

# Run tests
npm run test:backend
```

## 5. Start Developing

### Common Commands

```bash
# Start development server
npm run dev

# Start with Electron MCP (for E2E testing)
npm run dev:mcp

# Create a spec
cd apps/backend
python spec_runner.py --interactive

# Run autonomous build
python run.py --spec 001

# Run QA validation
python run.py --spec 001 --qa
```

### Beads Task Management

```bash
# Create task
bd create "Implement feature X"

# List tasks
bd list

# Show ready work
bd ready

# Update status
bd update Auto-Claude-<hash> --status in_progress
```

## Troubleshooting

### Container won't build
```bash
# Check Docker
docker ps

# Rebuild container
# Press F1 → "Rebuild Container"
```

### Python issues
```bash
cd apps/backend
rm -rf .venv
uv venv
uv pip install -r requirements.txt
```

### Node issues
```bash
rm -rf node_modules apps/frontend/node_modules
npm run install:all
```

### Git safe directory
```bash
git config --global --add safe.directory /workspaces/Auto-Claude
```

## Key Paths

- Backend: `/workspaces/Auto-Claude/apps/backend`
- Frontend: `/workspaces/Auto-Claude/apps/frontend`
- Python venv: `/workspaces/Auto-Claude/apps/backend/.venv`
- Tests: `/workspaces/Auto-Claude/tests`

## Port Forwarding

The following ports are automatically forwarded:

- **9222**: Electron remote debugging
- **3000**: Frontend dev server
- **5173**: Vite dev server

Access in browser: `http://localhost:<port>`

## Next Steps

- Read [.devcontainer/README.md](.devcontainer/README.md) for detailed documentation
- Read [CLAUDE.md](../CLAUDE.md) for project architecture and guidelines
- Read [DEVCONTAINER.md](../DEVCONTAINER.md) for devcontainer benefits and comparison

## Getting Help

- Check [.devcontainer/README.md#troubleshooting](.devcontainer/README.md#troubleshooting)
- Search [GitHub Issues](https://github.com/AndyMik90/Auto-Claude/issues)
- Join [Discord community](https://discord.gg/KCXaPBr4Dj)
