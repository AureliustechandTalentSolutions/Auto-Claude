# Development Container Support

Auto-Claude now supports development in containerized environments using VSCode Remote Containers and GitHub Codespaces. This provides a consistent, reproducible development environment across all platforms.

## Quick Start

### VSCode Remote Containers

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Install the [Remote - Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
3. Open the project in VSCode
4. Press `F1` → Select `Remote-Containers: Reopen in Container`
5. Wait for setup to complete (~5-10 minutes first time)

### GitHub Codespaces

1. Go to the [Auto-Claude repository](https://github.com/AndyMik90/Auto-Claude)
2. Click `Code` → `Codespaces` → `Create codespace on develop`
3. Wait for setup to complete (~5-10 minutes first time)

## What's Included

The devcontainer provides:

- **Python 3.12+** with virtual environment pre-configured
- **Node.js 24+** with all npm dependencies installed
- **uv** package manager for fast Python installs
- **Beads** task management (v0.47.1)
- **GitHub CLI** for PR and issue management
- **Docker-in-Docker** for containerized workflows
- **VSCode extensions** for Python, TypeScript, React, Git, and more
- **Port forwarding** for Electron debugging (9222) and dev servers (3000, 5173)

All dependencies are automatically installed, and environment files are created from examples.

## Post-Setup Steps

### 1. Configure API Keys

Edit `apps/backend/.env`:

```bash
# Required: Claude Code OAuth token
CLAUDE_CODE_OAUTH_TOKEN=your-token

# Required: Graphiti memory provider
GRAPHITI_ENABLED=true
OPENAI_API_KEY=sk-...          # For OpenAI
# OR
ANTHROPIC_API_KEY=sk-ant-...   # For Anthropic

# Optional: Enable Electron E2E testing
ELECTRON_MCP_ENABLED=true
```

### 2. Authenticate Claude CLI

```bash
claude
# Type: /login
# Complete OAuth flow in browser
```

### 3. Verify Installation

```bash
# Test backend
cd apps/backend && python run.py --list

# Test frontend
npm run dev

# Run tests
npm run test:backend
```

## Benefits

### Consistency
- Same environment for all developers
- No "works on my machine" issues
- Identical setup across Windows, macOS, and Linux

### Speed
- Pre-configured with all tools
- Automated dependency installation
- Fast rebuilds with layer caching

### Isolation
- Doesn't pollute your local system
- Multiple projects with different dependencies
- Easy to reset or rebuild

### Collaboration
- Share environment configuration in git
- Onboard new developers in minutes
- Reproducible CI/CD environments

## Documentation

For detailed documentation, troubleshooting, and customization, see:

- [.devcontainer/README.md](.devcontainer/README.md) - Complete devcontainer guide
- [CLAUDE.md](CLAUDE.md) - Main development documentation

## Comparison: Local vs Devcontainer

| Feature | Local Development | Devcontainer |
|---------|------------------|--------------|
| Setup Time | 15-30 minutes (manual) | 5-10 minutes (automated) |
| Dependencies | Install on your system | Isolated in container |
| Consistency | Varies by system | Identical for everyone |
| Python Version | Your system version | Python 3.12+ guaranteed |
| Node.js Version | Your system version | Node 24+ guaranteed |
| Platform Issues | Possible (Win/Mac/Linux) | Minimal (Ubuntu base) |
| Easy Reset | No (manual cleanup) | Yes (rebuild container) |
| Resource Usage | Native (fastest) | Slight overhead |

## When to Use

### Use Devcontainer When:
- You want a quick, automated setup
- You're new to the project
- You develop on Windows and face platform issues
- You want to avoid installing tools globally
- You're using GitHub Codespaces
- You want to ensure CI/CD parity

### Use Local Development When:
- You have a working local setup
- You need maximum performance
- You prefer managing dependencies yourself
- You don't want to run Docker
- You need access to native system tools

## Transitioning from Local to Devcontainer

If you're currently developing locally:

1. **Commit your work**: Ensure all changes are committed or stashed
2. **Open in container**: Follow the Quick Start steps above
3. **Verify setup**: Run tests to ensure everything works
4. **Continue working**: Your git history and files are preserved

Your local files are mounted into the container, so no data is lost.

## Troubleshooting

Common issues and solutions:

### Container won't build
- Check Docker is running: `docker ps`
- Rebuild: Press `F1` → `Remote-Containers: Rebuild Container`

### Python venv issues
```bash
cd apps/backend
rm -rf .venv && uv venv && uv pip install -r requirements.txt
```

### Node modules issues
```bash
rm -rf node_modules apps/frontend/node_modules
npm run install:all
```

For more troubleshooting, see [.devcontainer/README.md](.devcontainer/README.md#troubleshooting).

## Resources

- [VSCode Remote Containers](https://code.visualstudio.com/docs/remote/containers)
- [GitHub Codespaces](https://docs.github.com/en/codespaces)
- [Dev Containers Specification](https://containers.dev/)

## Support

For devcontainer-specific issues, see the [.devcontainer/README.md](.devcontainer/README.md) troubleshooting section.

For general Auto-Claude support, see [CLAUDE.md](CLAUDE.md).
