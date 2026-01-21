#!/bin/bash
# Verification script for Auto-Claude devcontainer setup
# Run this after the container is built to verify everything is working

set -e

echo "=========================================="
echo "Auto-Claude Devcontainer Verification"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is NOT installed"
        FAILED=1
        return 1
    fi
}

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} File exists: $1"
        return 0
    else
        echo -e "${RED}✗${NC} File missing: $1"
        FAILED=1
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} Directory exists: $1"
        return 0
    else
        echo -e "${RED}✗${NC} Directory missing: $1"
        FAILED=1
        return 1
    fi
}

# Check commands
echo "Checking installed tools..."
check_command python3
check_command node
check_command npm
check_command git
check_command gh
check_command uv
check_command bd
echo ""

# Check Python version
echo "Checking Python version..."
PYTHON_VERSION=$(python3 --version | grep -oP '\d+\.\d+')
if (( $(echo "$PYTHON_VERSION >= 3.12" | bc -l) )); then
    echo -e "${GREEN}✓${NC} Python version: $PYTHON_VERSION (>= 3.12)"
else
    echo -e "${RED}✗${NC} Python version: $PYTHON_VERSION (< 3.12 required)"
    FAILED=1
fi
echo ""

# Check Node version
echo "Checking Node.js version..."
NODE_VERSION=$(node --version | grep -oP '\d+' | head -1)
if [ "$NODE_VERSION" -ge 24 ]; then
    echo -e "${GREEN}✓${NC} Node.js version: v$NODE_VERSION (>= 24)"
else
    echo -e "${RED}✗${NC} Node.js version: v$NODE_VERSION (< 24 required)"
    FAILED=1
fi
echo ""

# Check directories
echo "Checking project structure..."
check_dir "/workspaces/Auto-Claude/apps/backend"
check_dir "/workspaces/Auto-Claude/apps/frontend"
check_dir "/workspaces/Auto-Claude/tests"
check_dir "/workspaces/Auto-Claude/scripts"
echo ""

# Check Python virtual environment
echo "Checking Python virtual environment..."
check_dir "/workspaces/Auto-Claude/apps/backend/.venv"
if [ -f "/workspaces/Auto-Claude/apps/backend/.venv/bin/python" ]; then
    echo -e "${GREEN}✓${NC} Python virtual environment is configured"
    VENV_VERSION=$(/workspaces/Auto-Claude/apps/backend/.venv/bin/python --version)
    echo "  Virtual environment Python: $VENV_VERSION"
else
    echo -e "${RED}✗${NC} Python virtual environment is not properly configured"
    FAILED=1
fi
echo ""

# Check Node modules
echo "Checking Node.js dependencies..."
if [ -d "/workspaces/Auto-Claude/node_modules" ]; then
    echo -e "${GREEN}✓${NC} Root node_modules exists"
else
    echo -e "${YELLOW}⚠${NC} Root node_modules missing (may be expected)"
fi

if [ -d "/workspaces/Auto-Claude/apps/frontend/node_modules" ]; then
    echo -e "${GREEN}✓${NC} Frontend node_modules exists"
else
    echo -e "${RED}✗${NC} Frontend node_modules missing"
    FAILED=1
fi
echo ""

# Check configuration files
echo "Checking configuration files..."
check_file "/workspaces/Auto-Claude/apps/backend/.env"
check_file "/workspaces/Auto-Claude/apps/frontend/.env"
check_file "/workspaces/Auto-Claude/package.json"
check_file "/workspaces/Auto-Claude/apps/backend/requirements.txt"
echo ""

# Check Beads initialization
echo "Checking Beads task management..."
if [ -d "/workspaces/Auto-Claude/.beads" ]; then
    echo -e "${GREEN}✓${NC} Beads is initialized"
    if [ -f "/workspaces/Auto-Claude/.beads/config.yaml" ]; then
        echo -e "${GREEN}✓${NC} Beads config exists"
    fi
else
    echo -e "${RED}✗${NC} Beads is not initialized"
    FAILED=1
fi
echo ""

# Test Python imports
echo "Testing Python imports..."
if /workspaces/Auto-Claude/apps/backend/.venv/bin/python -c "import anthropic" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Can import anthropic"
else
    echo -e "${YELLOW}⚠${NC} Cannot import anthropic (may need API key setup)"
fi

if /workspaces/Auto-Claude/apps/backend/.venv/bin/python -c "import dotenv" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Can import dotenv"
else
    echo -e "${RED}✗${NC} Cannot import dotenv"
    FAILED=1
fi
echo ""

# Summary
echo "=========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Your devcontainer is ready to use."
    echo ""
    echo "Next steps:"
    echo "1. Configure API keys in apps/backend/.env"
    echo "2. Authenticate Claude CLI: claude (then type /login)"
    echo "3. Start development: npm run dev"
    exit 0
else
    echo -e "${RED}✗ Some checks failed${NC}"
    echo ""
    echo "Please review the errors above and:"
    echo "1. Rebuild the container: Ctrl+Shift+P → 'Rebuild Container'"
    echo "2. Run the post-create script manually: bash .devcontainer/post-create.sh"
    echo "3. Check the troubleshooting guide: .devcontainer/README.md"
    exit 1
fi
