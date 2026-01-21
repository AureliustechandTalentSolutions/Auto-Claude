# Devcontainer Configuration Details

This document explains the technical details of the Auto-Claude devcontainer configuration.

## Container Configuration

### Base Image
```json
"image": "mcr.microsoft.com/devcontainers/base:ubuntu"
```

Using Microsoft's official base Ubuntu image for devcontainers. This provides:
- Latest Ubuntu LTS
- Common utilities pre-installed
- Non-root user (`vscode`) configured
- Optimized for VSCode Remote Containers

### Features (devcontainer features)

Features are pre-built, shareable configuration blocks maintained by Microsoft and the community.

#### Python 3.12
```json
"ghcr.io/devcontainers/features/python:1": {
  "version": "3.12",
  "installTools": true
}
```
- Installs Python 3.12.x (latest patch version)
- Includes pip, venv, and development tools
- Configures PATH automatically

#### Node.js 24
```json
"ghcr.io/devcontainers/features/node:1": {
  "version": "24",
  "nodeGypDependencies": true,
  "installYarnUsingApt": false
}
```
- Installs Node.js 24.x LTS
- Includes npm 10+
- Installs node-gyp dependencies for native modules
- Skips Yarn (we use npm only)

#### Git (Latest)
```json
"ghcr.io/devcontainers/features/git:1": {
  "version": "latest",
  "ppa": true
}
```
- Latest Git from official PPA
- Includes git-lfs support
- Git credential helpers configured

#### GitHub CLI
```json
"ghcr.io/devcontainers/features/github-cli:1": {
  "version": "latest"
}
```
- Official GitHub CLI (`gh`) for PR/issue management
- Authenticated through VSCode's GitHub integration
- Used by Auto-Claude for GitHub integration features

#### Common Utilities
```json
"ghcr.io/devcontainers/features/common-utils:2": {
  "installZsh": true,
  "installOhMyZsh": true,
  "upgradePackages": true,
  "username": "vscode",
  "uid": "1000",
  "gid": "1000"
}
```
- Zsh shell with Oh My Zsh
- Non-root user with sudo access
- Common CLI tools (curl, wget, jq, etc.)
- System packages kept up to date

#### Docker-in-Docker
```json
"ghcr.io/devcontainers/features/docker-in-docker:2": {
  "version": "latest",
  "moby": true,
  "dockerDashComposeVersion": "v2"
}
```
- Docker CLI and daemon inside container
- Docker Compose v2
- Allows containerized workflows (if needed in future)
- Uses Moby engine (open-source Docker)

## VSCode Customization

### Extensions

All extensions are automatically installed when container is created:

**Python Development:**
- `ms-python.python` - Python language support
- `ms-python.vscode-pylance` - Fast Python language server
- `ms-python.black-formatter` - Code formatting

**JavaScript/TypeScript:**
- `dbaeumer.vscode-eslint` - ESLint integration
- `esbenp.prettier-vscode` - Prettier formatting
- `biomejs.biome` - Fast linter/formatter (primary for this project)

**React/Frontend:**
- `styled-components.vscode-styled-components` - Styled components support
- `bradlc.vscode-tailwindcss` - Tailwind CSS IntelliSense

**Git:**
- `eamodio.gitlens` - Enhanced git features

**Utilities:**
- `EditorConfig.EditorConfig` - EditorConfig support
- `mikestead.dotenv` - .env file syntax
- `redhat.vscode-yaml` - YAML language support
- `tamasfe.even-better-toml` - TOML language support
- `ms-vscode.makefile-tools` - Makefile support

**AI (optional):**
- `GitHub.copilot` - GitHub Copilot
- `GitHub.copilot-chat` - Copilot Chat
- These only work if you have Copilot access

### Settings

Key VSCode settings configured:

```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/apps/backend/.venv/bin/python",
  "python.terminal.activateEnvironment": true,
  "editor.formatOnSave": true,
  "files.eol": "\n",
  "terminal.integrated.defaultProfile.linux": "zsh"
}
```

**Python:**
- Virtual environment at `apps/backend/.venv` auto-detected
- Auto-activate venv in terminal
- Black formatter for Python files
- Flake8 linting enabled

**Editor:**
- Format on save enabled
- Unix line endings (LF) enforced
- Biome formatter for TS/JS/JSON
- ESLint auto-fix on save

**Terminal:**
- Zsh as default shell
- Oh My Zsh themes and plugins available

## Port Forwarding

Ports are automatically forwarded from container to host:

```json
"forwardPorts": [9222, 3000, 5173]
```

| Port | Purpose | Auto-Forward |
|------|---------|-------------|
| 9222 | Electron remote debugging (Chrome DevTools Protocol) | Silent |
| 3000 | Frontend dev server (Electron Vite) | Notify |
| 5173 | Vite dev server (if running separately) | Notify |

Access via: `http://localhost:<port>` in your browser.

## Lifecycle Commands

### postCreateCommand
```bash
bash .devcontainer/post-create.sh
```

Runs once after container is created. Installs:
1. uv package manager
2. Python backend dependencies
3. Node.js frontend dependencies
4. Beads task management
5. Creates .env files from examples
6. Initializes git worktree directories

This command can take 5-10 minutes on first run.

### postStartCommand
```bash
git config --global --add safe.directory ${containerWorkspaceFolder}
```

Runs every time container starts. Ensures git operations work correctly by marking workspace as safe directory.

## Environment Variables

### Container Environment
```json
"containerEnv": {
  "WORKSPACE_FOLDER": "${containerWorkspaceFolder}",
  "NODE_ENV": "development"
}
```

### Remote Environment
```json
"remoteEnv": {
  "PATH": "${containerEnv:PATH}:/home/vscode/.local/bin:/workspaces/Auto-Claude/apps/backend/.venv/bin"
}
```

Extends PATH to include:
- User-local binaries (`~/.local/bin`) - where `uv` and `bd` are installed
- Python virtual environment - for direct access to Python tools

## Volume Mounts

### SSH Keys (Read-only)
```json
"source=${localEnv:HOME}${localEnv:USERPROFILE}/.ssh,target=/home/vscode/.ssh,readonly"
```
- Mounts your SSH keys into container
- Read-only for security
- Allows git operations with SSH remotes
- Works on Windows (USERPROFILE) and Unix (HOME)

### Git Config (Read-only)
```json
"source=${localEnv:HOME}${localEnv:USERPROFILE}/.gitconfig,target=/home/vscode/.gitconfig,readonly"
```
- Mounts your git configuration
- Preserves git user.name and user.email
- Includes git aliases and preferences

## Container Runtime

### Container Name
```json
"runArgs": [
  "--name=auto-claude-dev",
  "--hostname=auto-claude-dev"
]
```
- Named container for easy management
- Hostname set for better terminal prompts
- Allows `docker exec -it auto-claude-dev bash` access

### User
```json
"remoteUser": "vscode"
```
- Runs as non-root user `vscode` (UID 1000)
- Has sudo access for installing additional packages
- Matches typical Linux user setup

## Performance Considerations

### Layer Caching
- Features are cached independently
- Rebuilds only changed layers
- First build: ~5-10 minutes
- Subsequent builds: ~1-2 minutes

### Resource Requirements

**Minimum:**
- CPU: 2 cores
- RAM: 4 GB
- Disk: 10 GB

**Recommended (for Codespaces):**
- CPU: 4 cores
- RAM: 8 GB
- Disk: 32 GB

### Optimization Tips

1. **Use Docker BuildKit**: Enable in Docker Desktop settings
2. **Increase Docker Resources**: Give Docker more CPU/RAM
3. **Exclude Large Directories**: Add to `.dockerignore`
4. **Use Prebuilds**: For Codespaces, configure prebuilds to cache the built container

## Customization

### Adding System Packages

Edit `.devcontainer/post-create.sh`:

```bash
# Add after log_info messages
sudo apt-get update
sudo apt-get install -y your-package
```

### Adding VSCode Extensions

Edit `.devcontainer/devcontainer.json`:

```json
{
  "customizations": {
    "vscode": {
      "extensions": [
        "publisher.extension-id"
      ]
    }
  }
}
```

Find extension IDs in VSCode marketplace or by clicking extension → Copy Extension ID.

### Changing Feature Versions

Edit `.devcontainer/devcontainer.json`:

```json
{
  "features": {
    "ghcr.io/devcontainers/features/python:1": {
      "version": "3.13"  // Change version
    }
  }
}
```

After changes, rebuild container: `Ctrl+Shift+P` → `Rebuild Container`

## Security Notes

1. **SSH Keys are Read-only**: Cannot be modified from container
2. **Git Config is Read-only**: Prevents accidental changes
3. **Non-root User**: Prevents accidental system modifications
4. **Isolated Network**: Container has own network namespace
5. **No Secrets in Image**: All secrets in environment files (gitignored)

## Troubleshooting

### Container Build Fails

Check Docker Desktop is running:
```bash
docker ps
```

View build logs:
```bash
docker logs auto-claude-dev
```

### Post-create Script Fails

Run manually to see detailed errors:
```bash
bash .devcontainer/post-create.sh
```

### Features Not Installing

Clear Docker build cache:
```bash
docker builder prune -a
```

Rebuild container: `Ctrl+Shift+P` → `Rebuild Container`

### Slow Performance

1. Increase Docker resources (CPU/RAM)
2. Enable Docker BuildKit
3. Check disk space: `df -h`
4. Close other Docker containers

## References

- [Dev Containers Specification](https://containers.dev/)
- [VSCode Remote Containers](https://code.visualstudio.com/docs/remote/containers)
- [GitHub Codespaces](https://docs.github.com/en/codespaces)
- [Dev Container Features](https://containers.dev/features)
- [Microsoft Dev Container Images](https://github.com/devcontainers/images)
