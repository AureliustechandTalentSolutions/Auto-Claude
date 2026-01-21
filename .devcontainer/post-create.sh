#!/bin/bash
set -e

echo "=========================================="
echo "Auto-Claude Devcontainer Setup"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get workspace folder
WORKSPACE_FOLDER="${WORKSPACE_FOLDER:-/workspaces/Auto-Claude}"
cd "$WORKSPACE_FOLDER"

# ==========================================
# 1. Install uv package manager
# ==========================================
log_info "Installing uv package manager..."
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    log_info "uv installed successfully"
else
    log_info "uv already installed"
fi

# ==========================================
# 2. Setup Python backend
# ==========================================
log_info "Setting up Python backend..."
cd "$WORKSPACE_FOLDER/apps/backend"

# Create virtual environment
if [ ! -d ".venv" ]; then
    log_info "Creating Python virtual environment..."
    uv venv
else
    log_info "Virtual environment already exists"
fi

# Install backend dependencies
log_info "Installing backend dependencies..."
uv pip install -r requirements.txt

# Install test dependencies
if [ -f "../../tests/requirements-test.txt" ]; then
    log_info "Installing test dependencies..."
    uv pip install -r ../../tests/requirements-test.txt
fi

# Create .env from example if it doesn't exist
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    log_info "Creating backend .env from .env.example..."
    cp .env.example .env
    log_warn "Please configure your API keys in apps/backend/.env"
fi

# ==========================================
# 3. Setup Node.js frontend
# ==========================================
log_info "Setting up Node.js frontend..."
cd "$WORKSPACE_FOLDER"

# Update npm to latest
log_info "Updating npm to latest version..."
npm install -g npm@latest

# Install Beads globally
log_info "Installing Beads task management..."
if ! command -v bd &> /dev/null; then
    npm install -g @beads/bd@0.47.1
    log_info "Beads installed successfully"
else
    log_info "Beads already installed"
fi

# Initialize Beads if not already done
if [ ! -d ".beads" ]; then
    log_info "Initializing Beads..."
    bd init --name "Auto-Claude" --prefix "Auto-Claude"
else
    log_info "Beads already initialized"
fi

# Install root dependencies
log_info "Installing root dependencies..."
npm install

# Install backend dependencies via script
log_info "Running backend installation script..."
npm run install:backend

# Install frontend dependencies
log_info "Installing frontend dependencies..."
npm run install:frontend

# Create frontend .env from example if it doesn't exist
if [ ! -f "apps/frontend/.env" ] && [ -f "apps/frontend/.env.example" ]; then
    log_info "Creating frontend .env from .env.example..."
    cp apps/frontend/.env.example apps/frontend/.env
fi

# ==========================================
# 4. Setup Git hooks (optional)
# ==========================================
if [ -d "apps/frontend/node_modules/husky" ]; then
    log_info "Setting up Git hooks with husky..."
    cd "$WORKSPACE_FOLDER/apps/frontend"
    npm run prepare 2>/dev/null || log_warn "Husky setup skipped (may not be configured)"
fi

# ==========================================
# 5. Configure Git
# ==========================================
log_info "Configuring Git..."
cd "$WORKSPACE_FOLDER"

# Add safe directory (in case not done by postStartCommand)
git config --global --add safe.directory "$WORKSPACE_FOLDER" 2>/dev/null || true

# Set up git worktree directories
log_info "Creating git worktree directories..."
mkdir -p .worktrees
mkdir -p .auto-claude/specs

# ==========================================
# 6. Claude CLI Installation (optional)
# ==========================================
log_info "Checking for Claude CLI..."
if ! command -v claude &> /dev/null; then
    log_warn "Claude CLI not found. Install it from: https://claude.ai/download"
    log_warn "After container is running, authenticate with: claude (then type /login)"
else
    log_info "Claude CLI already installed"
fi

# ==========================================
# 7. Verify Installation
# ==========================================
log_info ""
log_info "=========================================="
log_info "Verification"
log_info "=========================================="

# Check Python
PYTHON_VERSION=$(apps/backend/.venv/bin/python --version 2>&1)
log_info "Python: $PYTHON_VERSION"

# Check Node
NODE_VERSION=$(node --version)
log_info "Node.js: $NODE_VERSION"

# Check npm
NPM_VERSION=$(npm --version)
log_info "npm: $NPM_VERSION"

# Check uv
UV_VERSION=$(uv --version 2>&1 || echo "not found")
log_info "uv: $UV_VERSION"

# Check Beads
BD_VERSION=$(bd --version 2>&1 || echo "not found")
log_info "Beads: $BD_VERSION"

# Check gh CLI
GH_VERSION=$(gh --version 2>&1 | head -n1 || echo "not found")
log_info "GitHub CLI: $GH_VERSION"

# Check Claude CLI
CLAUDE_VERSION=$(claude --version 2>&1 || echo "not found")
log_info "Claude CLI: $CLAUDE_VERSION"

# ==========================================
# 8. Final Instructions
# ==========================================
log_info ""
log_info "=========================================="
log_info "Setup Complete!"
log_info "=========================================="
log_info ""
log_info "Next steps:"
log_info "1. Configure API keys in apps/backend/.env"
log_info "2. Authenticate Claude CLI: claude (then type /login)"
log_info "3. Test backend: cd apps/backend && python run.py --list"
log_info "4. Test frontend: npm run dev"
log_info "5. Run tests: npm run test:backend"
log_info ""
log_info "For E2E testing with Electron MCP:"
log_info "- Set ELECTRON_MCP_ENABLED=true in apps/backend/.env"
log_info "- Start app with: npm run dev:mcp"
log_info ""
log_info "Beads task management:"
log_info "- Create task: bd create \"Task description\""
log_info "- List tasks: bd list"
log_info "- View ready work: bd ready"
log_info ""
log_info "Happy coding!"
