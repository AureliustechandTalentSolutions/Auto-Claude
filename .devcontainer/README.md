# Auto-Claude Development Container

This directory contains the configuration for developing Auto-Claude in a containerized environment using VSCode Remote Containers or GitHub Codespaces.

## What's Included

### Base Environment
- **OS**: Ubuntu (latest)
- **Python**: 3.12+ (with venv and pip)
- **Node.js**: 24.x LTS
- **Git**: Latest version with GitHub CLI
- **Docker**: Docker-in-Docker for containerized workflows

### Tools & Package Managers
- **uv**: Fast Python package installer
- **npm**: Node package manager (v10+)
- **Beads**: Git-backed task management (v0.47.1)
- **Claude CLI**: Claude Code authentication

### VSCode Extensions
- **Python**: Python, Pylance, Black formatter
- **JavaScript/TypeScript**: ESLint, Prettier, Biome
- **Git**: GitLens
- **Utilities**: EditorConfig, dotenv, YAML, TOML support
- **AI**: GitHub Copilot (if you have access)
- **Styling**: Tailwind CSS IntelliSense

### Pre-configured Features
- Python virtual environment at `apps/backend/.venv`
- All npm dependencies installed
- Git configuration with safe.directory
- Environment files created from examples
- Git hooks configured
- Port forwarding for:
  - 9222 (Electron remote debugging)
  - 3000 (Frontend dev server)
  - 5173 (Vite dev server)

## Getting Started

### Option 1: VSCode Remote Containers

1. **Prerequisites**:
   - Install [Docker Desktop](https://www.docker.com/products/docker-desktop)
   - Install [VSCode](https://code.visualstudio.com/)
   - Install the [Remote - Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

2. **Open in Container**:
   ```bash
   # Clone the repository
   git clone https://github.com/AndyMik90/Auto-Claude.git
   cd Auto-Claude

   # Open in VSCode
   code .
   ```

3. **Reopen in Container**:
   - Press `F1` or `Ctrl+Shift+P` (Cmd+Shift+P on Mac)
   - Select: `Remote-Containers: Reopen in Container`
   - Wait for the container to build and setup to complete (~5-10 minutes first time)

### Option 2: GitHub Codespaces

1. **Create a Codespace**:
   - Go to the [Auto-Claude repository](https://github.com/AndyMik90/Auto-Claude)
   - Click the green `Code` button
   - Select the `Codespaces` tab
   - Click `Create codespace on develop`

2. **Wait for Setup**:
   - The codespace will automatically build and run the post-create script
   - Setup takes ~5-10 minutes on first launch

## Post-Setup Configuration

### 1. Configure API Keys

Edit `apps/backend/.env` and add your API keys:

```bash
# Required: Claude Code OAuth token
# Run: claude (then type /login) to authenticate
CLAUDE_CODE_OAUTH_TOKEN=your-oauth-token

# Required: Graphiti memory (choose one provider)
GRAPHITI_ENABLED=true
OPENAI_API_KEY=sk-...          # For OpenAI
# OR
ANTHROPIC_API_KEY=sk-ant-...   # For Anthropic
VOYAGE_API_KEY=pa-...          # (pair with Anthropic)

# Optional: Linear integration
LINEAR_API_KEY=lin_api_...

# Optional: Electron E2E testing
ELECTRON_MCP_ENABLED=true
ELECTRON_DEBUG_PORT=9222
```

### 2. Authenticate Claude CLI

```bash
# In the terminal inside the container
claude
# Type: /login
# Press Enter to open browser and complete OAuth
```

### 3. Verify Setup

```bash
# Test backend
cd apps/backend
python run.py --list

# Test frontend
cd ../../
npm run dev

# Run tests
npm run test:backend
```

## Development Workflow

### Running the Application

```bash
# Start Electron frontend (development mode)
npm run dev

# Start with Electron MCP for E2E testing
npm run dev:mcp

# Start backend CLI directly
cd apps/backend
python run.py --spec 001
```

### Creating and Managing Specs

```bash
cd apps/backend

# Create a spec interactively
python spec_runner.py --interactive

# Create from task description
python spec_runner.py --task "Add user authentication"

# Run autonomous build
python run.py --spec 001

# Run QA validation
python run.py --spec 001 --qa
```

### Task Management with Beads

```bash
# Create new task
bd create "Implement feature X"

# List all tasks
bd list

# Show ready work (no blockers)
bd ready

# Update task status
bd update Auto-Claude-<hash> --status in_progress

# Close task
bd close Auto-Claude-<hash> --reason "Completed in PR #123"
```

### Testing

```bash
# Run all backend tests
npm run test:backend

# Run specific test
apps/backend/.venv/bin/pytest tests/test_security.py -v

# Run frontend tests
cd apps/frontend
npm test

# Run E2E tests
npm run test:e2e
```

### Code Quality

```bash
# Lint frontend
cd apps/frontend
npm run lint

# Format code
npm run format

# Type check
npm run typecheck
```

## Troubleshooting

### Container Won't Build

1. **Check Docker**:
   ```bash
   docker --version
   docker ps
   ```

2. **Rebuild Container**:
   - Press `F1` → `Remote-Containers: Rebuild Container`
   - Or delete the container and reopen:
     ```bash
     docker rm -f auto-claude-dev
     ```

### Python Virtual Environment Issues

```bash
# Recreate venv
cd apps/backend
rm -rf .venv
uv venv
uv pip install -r requirements.txt
```

### Node Modules Issues

```bash
# Clear and reinstall
rm -rf node_modules apps/frontend/node_modules
npm run install:all
```

### Git Issues

```bash
# Add safe directory
git config --global --add safe.directory /workspaces/Auto-Claude

# Reset git config
git config --global --unset-all safe.directory
```

### Port Forwarding Issues

If you can't access forwarded ports:

1. Check port forwarding in VSCode:
   - Press `F1` → `Ports: Focus on Ports View`
   - Ensure ports 9222, 3000, 5173 are forwarded

2. Manually forward a port:
   - In the Ports view, click `Forward a Port`
   - Enter the port number (e.g., 9222)

### Electron MCP Not Working

1. Ensure Electron is running with remote debugging:
   ```bash
   npm run dev:mcp
   ```

2. Check environment variable:
   ```bash
   grep ELECTRON_MCP_ENABLED apps/backend/.env
   ```

3. Verify port is accessible:
   ```bash
   curl http://localhost:9222/json/version
   ```

## Customization

### Adding VSCode Extensions

Edit `.devcontainer/devcontainer.json` and add to the `extensions` array:

```json
{
  "customizations": {
    "vscode": {
      "extensions": [
        "your.extension-id"
      ]
    }
  }
}
```

### Changing Python/Node Versions

Edit `.devcontainer/devcontainer.json`:

```json
{
  "features": {
    "ghcr.io/devcontainers/features/python:1": {
      "version": "3.13"
    },
    "ghcr.io/devcontainers/features/node:1": {
      "version": "22"
    }
  }
}
```

### Adding System Packages

Edit `.devcontainer/post-create.sh` and add:

```bash
sudo apt-get update
sudo apt-get install -y your-package
```

## Performance Tips

### Speed Up Rebuilds

1. **Use Layer Caching**: The devcontainer uses features which are cached
2. **Exclude Large Directories**: Add to `.dockerignore`:
   ```
   node_modules
   .venv
   dist
   .worktrees
   ```

3. **Increase Docker Resources**:
   - Docker Desktop → Settings → Resources
   - Increase CPU/Memory allocation

### Optimize for Codespaces

GitHub Codespaces recommendations:

1. **Use 4-core machine** for best performance
2. **Enable prebuilds** (requires admin access):
   - Go to repository Settings → Codespaces → Prebuilds
   - Add a prebuild configuration for `develop` branch

3. **Set default machine type**:
   ```json
   // .devcontainer/devcontainer.json
   {
     "hostRequirements": {
       "cpus": 4,
       "memory": "8gb",
       "storage": "32gb"
     }
   }
   ```

## Useful Commands

```bash
# Attach to running container
docker exec -it auto-claude-dev bash

# View container logs
docker logs auto-claude-dev

# Check container resource usage
docker stats auto-claude-dev

# Stop container
docker stop auto-claude-dev

# Remove container and rebuild
docker rm -f auto-claude-dev
# Then reopen in VSCode
```

## Known Issues

### Issue: SSH Keys Not Accessible

**Solution**: The devcontainer mounts your SSH keys as read-only. To use them:

```bash
# Copy to container (if needed for git operations)
cp -r ~/.ssh /home/vscode/.ssh-copy
chmod 600 /home/vscode/.ssh-copy/*
```

### Issue: Git Credentials Not Working

**Solution**: Configure git credential helper:

```bash
# Use system credential helper
git config --global credential.helper store

# Or use VSCode's credential helper
git config --global credential.helper "/usr/local/share/git-core/contrib/credential/git-credential-manager"
```

### Issue: Node-gyp Build Failures

**Solution**: Install build essentials:

```bash
sudo apt-get update
sudo apt-get install -y build-essential python3-dev
npm rebuild
```

## Resources

- [VSCode Remote Containers Docs](https://code.visualstudio.com/docs/remote/containers)
- [GitHub Codespaces Docs](https://docs.github.com/en/codespaces)
- [Dev Containers Specification](https://containers.dev/)
- [Auto-Claude Documentation](https://github.com/AndyMik90/Auto-Claude)

## Support

For issues with the devcontainer:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Search existing [GitHub Issues](https://github.com/AndyMik90/Auto-Claude/issues)
3. Create a new issue with:
   - Your environment (VSCode/Codespaces, OS, Docker version)
   - Error messages or logs
   - Steps to reproduce

For Auto-Claude specific issues, see the main [CLAUDE.md](/CLAUDE.md) documentation.
