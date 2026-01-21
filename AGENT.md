# AGENT.md

This document provides comprehensive guidance for working with the agent system in Auto-Claude. It complements CLAUDE.md by focusing specifically on the agent architecture, workflows, and implementation details.

## Overview

Auto-Claude is a multi-agent autonomous coding framework that uses specialized AI agents to build software through coordinated sessions. Each agent has a specific role in the development pipeline, from requirements gathering to implementation to quality assurance.

**Core Principle**: Agents work in isolated sessions with fresh context windows. They communicate through structured files (JSON specs, implementation plans, QA reports) rather than shared memory.

## Agent Architecture

### Design Philosophy

1. **Specialized Roles**: Each agent has a single, well-defined purpose
2. **Stateless Sessions**: Agents have no memory between sessions - all state is in files
3. **SDK-Based**: All agents use the Claude Agent SDK for consistent security and tooling
4. **Coordinated Pipeline**: Agents pass work through structured handoffs

### Agent Communication

Agents communicate through files in `.auto-claude/specs/XXX-name/`:

```
Spec Files (Communication Layer)
├── spec.md                      # Requirements (Spec Gatherer → All)
├── requirements.json            # Structured requirements
├── context.json                 # Codebase context
├── implementation_plan.json     # Work plan + status tracking
├── build-progress.txt          # Human-readable progress
├── qa_report.md                # QA findings (QA Reviewer → QA Fixer)
├── QA_FIX_REQUEST.md           # Issues to fix (QA Reviewer → QA Fixer)
└── memory/                     # Session insights (cross-session learning)
    ├── session_insights/       # Per-session learnings
    ├── patterns.md             # Code patterns discovered
    ├── gotchas.md              # Pitfalls to avoid
    └── codebase_map.json       # File purpose mapping
```

### Security Model

All agents run with three-layered security (configured in `core/client.py`):

1. **OS Sandbox**: Bash command isolation prevents filesystem escape
2. **Filesystem Permissions**: Operations restricted to project directory
3. **Command Allowlist**: Dynamic allowlist based on project stack (see `core/security.py`)

## Agent Types

### Implementation Agents

These agents handle the actual code building process.

#### Planner Agent

**Role**: Creates the initial implementation plan with subtask breakdown

**Location**: `apps/backend/agents/planner.py`
**Prompt**: `apps/backend/prompts/planner.md`
**Agent Type**: `"planner"`

**Responsibilities**:
- Deep codebase investigation (finds existing patterns)
- Creates `implementation_plan.json` with phases and subtasks
- Generates `init.sh` for environment setup
- Analyzes parallelism opportunities
- Defines verification strategy based on complexity

**Key Outputs**:
- `implementation_plan.json` - Complete subtask-based plan
- `project_index.json` - Project structure (if missing)
- `context.json` - Files to modify and patterns to follow
- `init.sh` - Setup script
- `build-progress.txt` - Progress tracking

**Example Usage**:
```python
from agents.planner import run_followup_planner

success = await run_followup_planner(
    project_dir=Path("/project"),
    spec_dir=Path(".auto-claude/specs/001"),
    model="claude-sonnet-4-5-20250929",
    verbose=True
)
```

**Workflow Types Supported**:
- **FEATURE**: Multi-service features (Backend → Worker → Frontend → Integration)
- **REFACTOR**: Stage-based changes (Add New → Migrate → Remove Old → Cleanup)
- **INVESTIGATION**: Bug hunting (Reproduce → Investigate → Fix → Harden)
- **MIGRATION**: Data pipeline (Prepare → Test → Execute → Cleanup)
- **SIMPLE**: Single-service quick tasks (no phases)

#### Coder Agent

**Role**: Implements subtasks from the implementation plan

**Location**: `apps/backend/agents/coder.py`
**Prompt**: `apps/backend/prompts/coder.md`
**Agent Type**: `"coder"`

**Responsibilities**:
- Reads implementation plan and finds next pending subtask
- Respects phase dependencies (won't work on blocked phases)
- Implements one subtask at a time
- Verifies each subtask before marking complete
- Commits progress with descriptive messages
- Updates session memory for cross-session learning

**Key Features**:
- **Subagent Support**: Can spawn parallel subagents for complex work via Task tool
- **Recovery Manager**: Tracks failed attempts and provides retry context
- **Memory Integration**: Reads patterns, gotchas, and session insights
- **Graphiti Context**: Retrieves relevant knowledge from graph memory

**Session Flow**:
```
1. Load context (plan, spec, memory)
2. Find next pending subtask (respects dependencies)
3. Start dev environment (init.sh)
4. Read subtask context (files to modify, patterns to follow)
5. Generate pre-implementation checklist (predict bugs)
6. Implement subtask (can use subagents)
7. Run self-critique checklist
8. Verify subtask (command/API/browser/e2e)
9. Update implementation_plan.json (status: completed)
10. Commit progress (with secret scanning)
11. Update build-progress.txt
12. Write session insights (optional)
```

**Example Run**:
```bash
cd apps/backend
python run.py --spec 001
```

**Critical Rules**:
- Never work on subtasks with unsatisfied dependencies
- Always verify before marking complete
- Fix bugs immediately (next session has no memory)
- Never commit spec files (`.auto-claude/` is gitignored)
- Never push to remote (user controls when to push)

#### QA Reviewer Agent

**Role**: Validates completed implementation before sign-off

**Prompt**: `apps/backend/prompts/qa_reviewer.md`
**Agent Type**: `"qa_reviewer"`

**Responsibilities**:
- Verifies all subtasks are completed
- Runs automated tests (unit, integration, e2e)
- Browser verification (console errors, visual checks, interactions)
- Database verification (migrations, schema)
- Security review (hardcoded secrets, vulnerabilities)
- Pattern compliance check
- Third-party API validation (via Context7)
- Regression testing
- Generates comprehensive QA report

**QA Validation Phases**:
```
Phase 0: Load Context (spec, plan, qa_acceptance criteria)
Phase 1: Verify All Subtasks Completed
Phase 2: Start Development Environment
Phase 3: Run Automated Tests
Phase 4: Browser Verification (if frontend)
Phase 5: Database Verification (if applicable)
Phase 6: Code Review (security, patterns, third-party APIs)
Phase 7: Regression Check
Phase 8: Generate QA Report
Phase 9: Update Implementation Plan (approved/rejected)
Phase 10: Signal Completion
```

**E2E Testing Capabilities**:

For frontend changes, QA Reviewer can perform automated E2E testing via Electron MCP:

```bash
# Enable in .env
ELECTRON_MCP_ENABLED=true
ELECTRON_DEBUG_PORT=9222

# Start app with remote debugging
npm run dev  # Already configured with --remote-debugging-port=9222
```

**Available E2E Tools**:
- `mcp__electron__get_electron_window_info` - Get window info
- `mcp__electron__take_screenshot` - Visual verification
- `mcp__electron__send_command_to_electron` - UI interactions:
  - `click_by_text` - Click buttons/links
  - `click_by_selector` - Click by CSS selector
  - `fill_input` - Fill forms
  - `select_option` - Select dropdowns
  - `send_keyboard_shortcut` - Keyboard actions
  - `navigate_to_hash` - Navigate routes
  - `get_page_structure` - Inspect page
  - `debug_elements` - Debug buttons/forms
  - `verify_form_state` - Check form validation
  - `eval` - Execute JavaScript
- `mcp__electron__read_electron_logs` - Read console logs

**QA Outcomes**:

1. **APPROVED**: Creates `qa_report.md`, updates `implementation_plan.json` with approval
2. **REJECTED**: Creates `QA_FIX_REQUEST.md` with detailed fix instructions for QA Fixer

#### QA Fixer Agent

**Role**: Fixes issues identified by QA Reviewer

**Prompt**: `apps/backend/prompts/qa_fixer.md`
**Agent Type**: `"qa_fixer"`

**Responsibilities**:
- Reads `QA_FIX_REQUEST.md` for issues to fix
- Implements fixes one by one
- Verifies each fix (can use E2E testing)
- Commits with "fix: [description] (qa-requested)"
- Returns control to QA Reviewer for re-validation

**Fix Loop**:
```
QA Reviewer finds issues
    ↓
Creates QA_FIX_REQUEST.md
    ↓
QA Fixer implements fixes
    ↓
Commits with (qa-requested)
    ↓
QA Reviewer re-runs validation
    ↓
APPROVED or REJECTED (loop continues)
```

**Maximum Iterations**: 5 (configurable)

If max iterations reached:
- Escalate to human review
- Save detailed report of remaining issues

### Spec Creation Agents

These agents create the initial specification before implementation begins.

#### Spec Gatherer Agent

**Prompt**: `apps/backend/prompts/spec_gatherer.md`
**Phase**: Discovery

**Responsibilities**:
- Loads project context from `project_index.json`
- Understands task description from user
- Determines workflow type (feature/refactor/investigation/migration/simple)
- Identifies services involved
- Gathers detailed requirements and constraints
- Creates `requirements.json`

**Output Format** (`requirements.json`):
```json
{
  "task_description": "Clear description of what to build",
  "workflow_type": "feature|refactor|investigation|migration|simple",
  "services_involved": ["service1", "service2"],
  "user_requirements": [
    "Requirement 1",
    "Requirement 2"
  ],
  "acceptance_criteria": [
    "Criterion 1",
    "Criterion 2"
  ],
  "constraints": [
    "Constraint or limitation"
  ],
  "created_at": "ISO timestamp"
}
```

#### Spec Researcher Agent

**Prompt**: `apps/backend/prompts/spec_researcher.md`
**Phase**: Research (optional, for complex tasks)

**Responsibilities**:
- Validates external integrations (APIs, libraries)
- Uses Context7 to fetch accurate documentation
- Identifies deprecated methods or breaking changes
- Validates security patterns
- Documents integration requirements

**Example Research**:
```python
# Research Stripe integration
1. resolve-library-id("stripe")
2. get-library-docs("stripe", "payments", mode="code")
3. Validate payment flow patterns
4. Document required configuration
```

#### Spec Writer Agent

**Prompt**: `apps/backend/prompts/spec_writer.md`
**Phase**: Spec Creation

**Responsibilities**:
- Reads `requirements.json`
- Creates comprehensive `spec.md`
- Documents workflow type and rationale
- Lists services and their roles
- Specifies files to modify and reference
- Defines success criteria
- Includes QA acceptance criteria

**Output Format** (`spec.md`):
```markdown
# Spec: [Feature Name]

## Overview
[Description]

## Workflow Type
**Type**: [feature|refactor|investigation|migration|simple]
**Rationale**: [Why this workflow]

## Services Involved
- **service1**: [Role]
- **service2**: [Role]

## Files to Modify
- `path/to/file1.py`: [Changes]
- `path/to/file2.ts`: [Changes]

## Files to Reference
- `path/to/pattern.py`: [Pattern to follow]

## Success Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## QA Acceptance Criteria
- Unit tests must pass
- Integration tests for [services]
- Browser verification: no console errors
- Database migrations applied
```

#### Spec Critic Agent

**Prompt**: `apps/backend/prompts/spec_critic.md`
**Phase**: Self-Critique (optional, for complex tasks)

**Responsibilities**:
- Reviews `spec.md` for completeness
- Uses ultrathink (16000 token budget) for deep analysis
- Identifies missing requirements or edge cases
- Suggests improvements
- Validates acceptance criteria

#### Complexity Assessor Agent

**Prompt**: `apps/backend/prompts/complexity_assessor.md`
**Phase**: Complexity Assessment

**Responsibilities**:
- Analyzes task requirements
- Assigns complexity level (trivial/low/medium/high/critical)
- Recommends validation strategy
- Determines if validation can be skipped (docs-only changes)
- Specifies test types required (unit/integration/e2e)
- Indicates if security scanning is needed

**Output Format** (`complexity_assessment.json`):
```json
{
  "complexity_level": "medium",
  "risk_level": "medium",
  "validation_recommendations": {
    "skip_validation": false,
    "test_types_required": ["unit", "integration"],
    "security_scan_required": false,
    "staging_deployment_required": false
  },
  "reasoning": "Changes affect business logic, requires test coverage"
}
```

### Spec Creation Pipeline

The spec creation process uses a dynamic pipeline (3-8 phases) based on complexity:

**SIMPLE** (3 phases):
```
Discovery → Quick Spec → Validate
```

**STANDARD** (6-7 phases):
```
Discovery → Requirements → [Research] → Context → Spec → Plan → Validate
```

**COMPLEX** (8 phases):
```
Discovery → Requirements → Research → Context → Spec → Self-Critique → Plan → Validate
```

**Run Spec Creation**:
```bash
cd apps/backend

# Interactive mode
python spec_runner.py --interactive

# From task description
python spec_runner.py --task "Add user authentication"

# Force complexity level
python spec_runner.py --task "Fix button" --complexity simple
```

## Agent Session Management

### Session Runner

**Location**: `apps/backend/agents/session.py`

**Key Functions**:

#### `run_agent_session()`

Runs a single agent session with streaming output:

```python
async def run_agent_session(
    client: ClaudeSDKClient,
    message: str,
    spec_dir: Path,
    verbose: bool = False,
    phase: LogPhase = LogPhase.CODING,
) -> tuple[str, str]:
    """
    Returns: (status, response_text)
    - status: "continue" | "complete" | "error"
    - response_text: Agent's response
    """
```

**Features**:
- Streams tool use and results in real-time
- Logs to persistent task logger
- Handles security hooks (blocked commands)
- Shows truncated errors and results
- Detects build completion

#### `post_session_processing()`

Processes session results automatically (100% reliable Python):

```python
async def post_session_processing(
    spec_dir: Path,
    project_dir: Path,
    subtask_id: str,
    session_num: int,
    commit_before: str | None,
    commit_count_before: int,
    recovery_manager: RecoveryManager,
    linear_enabled: bool = False,
    status_manager: StatusManager | None = None,
    source_spec_dir: Path | None = None,
) -> bool:
    """
    Returns: True if subtask completed successfully
    """
```

**Responsibilities**:
- Checks if subtask status was updated
- Counts new commits
- Records recovery attempts
- Records good commits for rollback safety
- Extracts session insights (LLM-powered)
- Saves to memory (Graphiti primary, file-based fallback)
- Updates Linear progress (if enabled)
- Updates ccstatusline status

**Why Automatic Processing?**

Agents cannot be relied upon to update memory correctly. Post-session processing runs in Python after each session to ensure:
- Memory is always saved (cross-session learning)
- Recovery tracking is accurate
- Linear integration is updated
- Status files are synchronized

### Client Factory

**Location**: `apps/backend/core/client.py`

**Key Function**: `create_client()`

Creates a configured Claude SDK client with phase-aware tools and security:

```python
from core.client import create_client

client = create_client(
    project_dir=Path("/project"),
    spec_dir=Path(".auto-claude/specs/001"),
    model="claude-sonnet-4-5-20250929",
    agent_type="coder",  # planner|coder|qa_reviewer|qa_fixer|spec_gatherer
    max_thinking_tokens=None,  # None|5000|10000|16000
    output_format=None,  # Optional structured output schema
    agents=None,  # Optional subagent definitions
)
```

**Security Configuration**:

```python
security_settings = {
    "sandbox": {"enabled": True, "autoAllowBashIfSandboxed": True},
    "permissions": {
        "defaultMode": "acceptEdits",
        "allow": [
            "Read(./**)",
            "Write(./**)",
            "Edit(./**)",
            "Glob(./**)",
            "Grep(./**)",
            "Bash(*)",  # Validated by bash_security_hook
            "WebFetch(*)",
            "WebSearch(*)",
            # MCP tools (context7, linear, graphiti, electron, puppeteer)
        ]
    }
}
```

**Agent-Specific Tools**:

Tools are filtered by agent type to prevent misuse:

| Agent Type | Core Tools | MCP Servers | Special Tools |
|------------|-----------|-------------|---------------|
| `planner` | Read, Write, Bash, Glob, Grep | Context7 | - |
| `coder` | Read, Write, Edit, Bash, Glob, Grep | Context7, Auto-Claude | Task (subagents) |
| `qa_reviewer` | Read, Bash, Glob, Grep | Context7, Electron/Puppeteer | Browser automation |
| `qa_fixer` | Read, Write, Edit, Bash, Glob, Grep | Context7, Electron/Puppeteer | Browser automation |
| `spec_gatherer` | Read, Write, Glob, Grep | Context7 | - |

**Extended Thinking Budgets**:

Different phases use different thinking token budgets:

| Phase | Budget | Use Case |
|-------|--------|----------|
| Planning | 5000 | Creating implementation plans |
| Coding | None | Fast iteration on subtasks |
| QA Review | 10000 | Thorough validation |
| Spec Creation | 16000 | Deep analysis (ultrathink) |

**MCP Server Configuration**:

MCP servers are dynamically started based on:
- Agent type
- Project capabilities (detected from codebase)
- Per-project configuration (`.auto-claude/.env`)

```python
# Only starts servers the agent needs
if "context7" in required_servers:
    mcp_servers["context7"] = {
        "command": "npx",
        "args": ["-y", "@upstash/context7-mcp"]
    }

if "electron" in required_servers:
    mcp_servers["electron"] = {
        "command": "npm",
        "args": ["exec", "electron-mcp-server"]
    }
```

## Memory System

### Architecture

Auto-Claude uses a dual-layer memory system:

1. **PRIMARY: Graphiti** (when enabled)
   - Semantic search over knowledge graph
   - Cross-session context retrieval
   - Pattern and gotcha extraction
   - Embedded LadybugDB (no Docker required)

2. **FALLBACK: File-based** (always available)
   - Zero dependencies
   - JSON files in `memory/session_insights/`
   - Patterns in `memory/patterns.md`
   - Gotchas in `memory/gotchas.md`

### Memory Manager

**Location**: `apps/backend/agents/memory_manager.py`

**Key Functions**:

#### `get_graphiti_context()`

Retrieves relevant context for the current subtask:

```python
async def get_graphiti_context(
    spec_dir: Path,
    project_dir: Path,
    subtask: dict,
) -> str | None:
    """
    Searches Graphiti knowledge graph for:
    - Relevant context items
    - Learned patterns (cross-session)
    - Known gotchas (cross-session)
    - Recent session history

    Returns: Formatted markdown context string
    """
```

**Example Output**:
```markdown
## Graphiti Memory Context

_Retrieved from knowledge graph for this subtask:_

### Relevant Knowledge
- **[implementation]** Database connections must be closed explicitly...
- **[pattern]** All API endpoints use APIRouter with prefix...

### Learned Patterns
_Patterns discovered in previous sessions:_
- **Pattern**: Error handling uses try/except with specific exceptions
  _Applies to:_ All service methods

### Known Gotchas
_Pitfalls to avoid:_
- **Gotcha**: API rate limit is 100 req/min
  _Solution:_ Implement rate limiting middleware

### Recent Session Insights
**Session 3 recommendations:**
- Focus on integration tests between services
- Review error handling in worker service
```

#### `save_session_memory()`

Saves session insights to memory:

```python
async def save_session_memory(
    spec_dir: Path,
    project_dir: Path,
    subtask_id: str,
    session_num: int,
    success: bool,
    subtasks_completed: list[str],
    discoveries: dict | None = None,
) -> tuple[bool, str]:
    """
    Saves to PRIMARY (Graphiti) if enabled, else FALLBACK (file-based).

    Returns: (success, storage_type)
    - storage_type: "graphiti" | "file" | "none"
    """
```

**Insights Structure**:
```python
insights = {
    "subtasks_completed": ["subtask-1", "subtask-2"],
    "discoveries": {
        "files_understood": {
            "path/to/file.py": "Description of what this file does"
        },
        "patterns_found": [
            "Pattern: use React hooks for state"
        ],
        "gotchas_encountered": [
            "Gotcha: database connections must be closed"
        ]
    },
    "what_worked": [
        "Starting with unit tests caught edge cases early"
    ],
    "what_failed": [
        "Tried inline validation - should use middleware"
    ],
    "recommendations_for_next_session": [
        "Focus on integration tests between services"
    ]
}
```

### Graphiti Configuration

**Location**: `apps/backend/graphiti_config.py`

**Setup** (`.auto-claude/.env`):
```bash
# Enable Graphiti
GRAPHITI_ENABLED=true

# LLM Provider (choose one)
ANTHROPIC_API_KEY=sk-ant-...
# OR
OPENAI_API_KEY=sk-...
# OR
AZURE_OPENAI_API_KEY=...
# OR
OLLAMA_HOST=http://localhost:11434

# Embedder Provider (choose one)
OPENAI_API_KEY=sk-...  # Reuse for embeddings
# OR
VOYAGE_API_KEY=pa-...
# OR
AZURE_OPENAI_API_KEY=...
# OR
OLLAMA_HOST=http://localhost:11434

# Optional: Database settings (defaults to embedded LadybugDB)
GRAPHITI_DB_HOST=localhost
GRAPHITI_DB_PORT=9999
GRAPHITI_DB_NAME=default
```

**Multi-Provider Support**:

| Provider | LLM | Embedder | Setup |
|----------|-----|----------|-------|
| Anthropic | ✓ | - | `ANTHROPIC_API_KEY` |
| OpenAI | ✓ | ✓ | `OPENAI_API_KEY` |
| Azure OpenAI | ✓ | ✓ | `AZURE_OPENAI_API_KEY` + endpoints |
| Ollama | ✓ | ✓ | `OLLAMA_HOST` |
| Google AI (Gemini) | ✓ | ✓ | `GOOGLE_AI_API_KEY` |
| Voyage AI | - | ✓ | `VOYAGE_API_KEY` |

## Tool Configuration

### Agent Tool Permissions

**Location**: `apps/backend/agents/tools_pkg/models.py`

**AGENT_CONFIGS** (Single Source of Truth):

```python
AGENT_CONFIGS = {
    "planner": {
        "tools": ["Read", "Write", "Bash", "Glob", "Grep", "WebFetch", "WebSearch"],
        "mcp_servers": ["context7"],
        "allow_mcp_add": True,
        "allow_mcp_remove": True
    },
    "coder": {
        "tools": [
            "Read", "Write", "Edit", "NotebookEdit",
            "Bash", "Glob", "Grep",
            "Task",  # Spawn subagents
            "WebFetch", "WebSearch"
        ],
        "mcp_servers": ["context7", "auto-claude"],
        "allow_mcp_add": True,
        "allow_mcp_remove": False  # Coder needs auto-claude tools
    },
    "qa_reviewer": {
        "tools": ["Read", "Bash", "Glob", "Grep", "WebFetch", "WebSearch"],
        "mcp_servers": ["context7", "electron OR puppeteer"],
        "project_detection": {
            "electron": "is_electron",
            "puppeteer": "!is_electron && has_frontend"
        },
        "allow_mcp_add": True,
        "allow_mcp_remove": True
    },
    "qa_fixer": {
        "tools": ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "WebFetch", "WebSearch"],
        "mcp_servers": ["context7", "electron OR puppeteer"],
        "project_detection": {
            "electron": "is_electron",
            "puppeteer": "!is_electron && has_frontend"
        },
        "allow_mcp_add": True,
        "allow_mcp_remove": True
    },
    "spec_gatherer": {
        "tools": ["Read", "Write", "Glob", "Grep", "WebFetch", "WebSearch"],
        "mcp_servers": ["context7"],
        "allow_mcp_add": True,
        "allow_mcp_remove": True
    }
}
```

### Project-Specific Tool Injection

**Location**: `apps/backend/context/project_analyzer.py`

**Capability Detection**:

```python
def detect_project_capabilities(project_index: dict) -> dict[str, bool]:
    """
    Detects project capabilities for dynamic tool injection.

    Returns:
        {
            "is_electron": bool,
            "is_web_frontend": bool,
            "has_frontend": bool,
            "has_database": bool,
            "has_testing": bool,
            ...
        }
    """
```

**Example Detection Logic**:
```python
# Electron detection
if "electron" in project_index.get("tech_stack", []):
    capabilities["is_electron"] = True

# Database detection
if any(db in tech_stack for db in ["postgresql", "mysql", "mongodb"]):
    capabilities["has_database"] = True
```

**Tool Injection Based on Capabilities**:

```python
# QA Reviewer gets Electron MCP for Electron apps
if project_capabilities["is_electron"]:
    mcp_servers["electron"] = {...}
    allowed_tools.extend(ELECTRON_TOOLS)

# QA Reviewer gets Puppeteer MCP for web frontends
elif project_capabilities["has_frontend"]:
    mcp_servers["puppeteer"] = {...}
    allowed_tools.extend(PUPPETEER_TOOLS)
```

### MCP Server Management

**Location**: `apps/backend/agents/tools_pkg/__init__.py`

**Available MCP Servers**:

| Server | Purpose | Required For |
|--------|---------|--------------|
| `context7` | Documentation lookup | All agents (optional) |
| `linear` | Project management | Optional (if `LINEAR_API_KEY` set) |
| `electron` | Desktop app automation | QA agents (Electron projects) |
| `puppeteer` | Browser automation | QA agents (web projects) |
| `graphiti-memory` | Knowledge graph memory | Optional (if `GRAPHITI_MCP_URL` set) |
| `auto-claude` | Custom spec tools | Coder agent (provides subtask tools) |

**Per-Project MCP Configuration**:

In `.auto-claude/.env`:

```bash
# Global toggles
CONTEXT7_ENABLED=true
LINEAR_MCP_ENABLED=true
ELECTRON_MCP_ENABLED=false
PUPPETEER_MCP_ENABLED=false

# Per-agent overrides
AGENT_MCP_coder_ADD=custom-mcp-server
AGENT_MCP_coder_REMOVE=context7
AGENT_MCP_qa_reviewer_ADD=custom-test-server

# Custom MCP servers
CUSTOM_MCP_SERVERS='[
  {
    "id": "my-server",
    "name": "My Custom Server",
    "type": "command",
    "command": "npx",
    "args": ["my-mcp-package"]
  }
]'
```

## Recovery and Retry

### Recovery Manager

**Location**: `apps/backend/recovery.py`

**Responsibilities**:
- Tracks failed subtask attempts
- Provides recovery context for retries
- Marks subtasks as stuck after 3 failures
- Records good commits for rollback

**Key Methods**:

```python
class RecoveryManager:
    def record_attempt(
        self,
        subtask_id: str,
        session: int,
        success: bool,
        approach: str,
        error: str | None = None
    ) -> None:
        """Records an attempt (success or failure)"""

    def get_attempt_count(self, subtask_id: str) -> int:
        """Returns number of previous attempts"""

    def get_recovery_hints(self, subtask_id: str) -> str | None:
        """Returns context about previous failures"""

    def mark_subtask_stuck(self, subtask_id: str, reason: str) -> None:
        """Marks subtask as stuck after 3 failures"""

    def record_good_commit(self, commit_hash: str, subtask_id: str) -> None:
        """Records a successful commit for rollback safety"""
```

**Recovery Flow**:

```
Attempt 1 → Failure
    ↓
record_attempt(subtask, session=1, success=False, error="...")
    ↓
Attempt 2 → get_recovery_hints(subtask)
    ↓ (includes previous error and approach)
Attempt 2 → Failure
    ↓
record_attempt(subtask, session=2, success=False, error="...")
    ↓
Attempt 3 → get_recovery_hints(subtask)
    ↓
Attempt 3 → Failure
    ↓
mark_subtask_stuck(subtask, reason="Failed after 3 attempts")
    ↓
Escalate to human or skip subtask
```

**Linear Integration** (if enabled):

Stuck subtasks are reported to Linear with:
- Subtask ID and description
- Number of attempts
- Error summary
- Link to spec directory

## Creating Custom Agents

### Step 1: Define Agent Configuration

Add to `apps/backend/agents/tools_pkg/models.py`:

```python
AGENT_CONFIGS["my_agent"] = {
    "tools": ["Read", "Write", "Bash", "Glob", "Grep"],
    "mcp_servers": ["context7"],
    "allow_mcp_add": True,
    "allow_mcp_remove": True
}
```

### Step 2: Create Agent Module

Create `apps/backend/agents/my_agent.py`:

```python
"""
My Custom Agent
===============

Description of what this agent does.
"""

import logging
from pathlib import Path

from core.client import create_client
from agents.session import run_agent_session

logger = logging.getLogger(__name__)

async def run_my_agent(
    project_dir: Path,
    spec_dir: Path,
    model: str,
    verbose: bool = False,
) -> bool:
    """
    Run my custom agent.

    Args:
        project_dir: Root directory for the project
        spec_dir: Directory containing the spec
        model: Claude model to use
        verbose: Whether to show detailed output

    Returns:
        True if successful
    """
    # Create client with agent-specific tools
    client = create_client(
        project_dir,
        spec_dir,
        model,
        agent_type="my_agent",
        max_thinking_tokens=5000,  # Optional
    )

    # Generate prompt for this agent
    prompt = generate_my_agent_prompt(spec_dir, project_dir)

    # Run agent session
    async with client:
        status, response = await run_agent_session(
            client, prompt, spec_dir, verbose
        )

    return status != "error"

def generate_my_agent_prompt(spec_dir: Path, project_dir: Path) -> str:
    """Generate the prompt for this agent"""
    # Read relevant context files
    spec_path = spec_dir / "spec.md"
    spec_content = spec_path.read_text() if spec_path.exists() else ""

    # Build prompt
    prompt = f"""
    YOUR ROLE - MY CUSTOM AGENT

    You are a custom agent that does X, Y, Z.

    Context:
    {spec_content}

    Your tasks:
    1. Task 1
    2. Task 2
    3. Task 3
    """

    return prompt
```

### Step 3: Create Agent Prompt

Create `apps/backend/prompts/my_agent.md`:

```markdown
## YOUR ROLE - MY CUSTOM AGENT

You are a custom agent in the Auto-Claude development pipeline. Your job is to [describe role].

**Key Principle**: [Core principle for this agent]

---

## PHASE 0: LOAD CONTEXT (MANDATORY)

```bash
# Read necessary files
cat spec.md
cat implementation_plan.json
```

---

## PHASE 1: DO THE WORK

[Step-by-step instructions]

---

## KEY REMINDERS

- Reminder 1
- Reminder 2

---

## BEGIN

Run Phase 0 now.
```

### Step 4: Add CLI Integration

Add to `apps/backend/run.py`:

```python
from agents.my_agent import run_my_agent

# Add CLI flag
parser.add_argument("--my-agent", action="store_true", help="Run my custom agent")

# Add execution path
if args.my_agent:
    success = asyncio.run(
        run_my_agent(
            project_dir=project_dir,
            spec_dir=spec_dir,
            model=args.model,
            verbose=args.verbose
        )
    )
    sys.exit(0 if success else 1)
```

## Agent Best Practices

### Writing Effective Agent Prompts

1. **Clear Role Definition**: Start with a clear role statement
2. **Structured Phases**: Break work into numbered phases
3. **Mandatory Checkpoints**: Use CRITICAL/MANDATORY markers for essential steps
4. **Example Commands**: Provide exact bash commands
5. **Output Formats**: Specify exact JSON/Markdown formats
6. **Reminders Section**: Repeat key rules at the end
7. **BEGIN Statement**: End with explicit "BEGIN" instruction

### Agent Session Management

1. **Fresh Context Windows**: Design agents to load all context from files
2. **Stateless Design**: No assumptions about previous sessions
3. **Explicit Handoffs**: Use structured files for agent-to-agent communication
4. **Checkpointing**: Save progress after each meaningful step
5. **Error Recovery**: Provide recovery hints for failed attempts

### Security Considerations

1. **Tool Restrictions**: Only give agents the tools they need
2. **Filesystem Boundaries**: Enforce project directory restrictions
3. **Command Allowlisting**: Use dynamic allowlists based on project stack
4. **Secret Scanning**: Automatic scanning before every commit
5. **Sandbox Enforcement**: Always run with OS-level sandbox

### Testing Custom Agents

```bash
# Test agent in isolation
cd apps/backend

# Create test spec
mkdir -p .auto-claude/specs/test-001

# Run agent
python -c "
import asyncio
from pathlib import Path
from agents.my_agent import run_my_agent

asyncio.run(
    run_my_agent(
        project_dir=Path.cwd(),
        spec_dir=Path('.auto-claude/specs/test-001'),
        model='claude-sonnet-4-5-20250929',
        verbose=True
    )
)
"
```

## Agent Workflow Examples

### Example 1: Feature Implementation

```
User Request: "Add user authentication with JWT"
    ↓
Spec Gatherer → requirements.json
    ↓
Spec Writer → spec.md
    ↓
Planner → implementation_plan.json
    ↓
Coder (Session 1) → Subtask 1: Create User model
    ↓
Coder (Session 2) → Subtask 2: Create auth endpoints
    ↓
Coder (Session 3) → Subtask 3: Add JWT middleware
    ↓
Coder (Session 4) → Subtask 4: Frontend login form
    ↓
QA Reviewer → qa_report.md (REJECTED)
    ↓
QA Fixer → Fix issues
    ↓
QA Reviewer → qa_report.md (APPROVED)
    ↓
Ready for merge
```

### Example 2: Bug Investigation

```
User Request: "Fix memory leak in worker process"
    ↓
Spec Gatherer → requirements.json (workflow_type: investigation)
    ↓
Spec Writer → spec.md
    ↓
Planner → implementation_plan.json
    Phase 1: Reproduce
    Phase 2: Investigate (BLOCKED until Phase 1)
    Phase 3: Fix (BLOCKED until Phase 2)
    Phase 4: Harden
    ↓
Coder (Phase 1) → Add logging, create repro steps
    ↓
Coder (Phase 2) → Identify root cause → INVESTIGATION.md
    ↓ (Phase 3 now unblocked)
Coder (Phase 3) → Implement fix
    ↓
Coder (Phase 4) → Add monitoring
    ↓
QA Reviewer → Verify fix works
```

### Example 3: Parallel Work

```
Planner creates plan with parallel phases:
    Phase 1: Backend API (depends_on: [])
    Phase 2: Worker (depends_on: [phase-1])
    Phase 3: Frontend (depends_on: [phase-1])
    Phase 4: Integration (depends_on: [phase-2, phase-3])

Execution:
    Phase 1 → Complete
        ↓
    Phase 2 (worker) + Phase 3 (frontend) run in parallel
        ↓
    Both Phase 2 and 3 complete
        ↓
    Phase 4 (integration) runs
```

## Debugging Agents

### Enable Debug Logging

```bash
# Set DEBUG environment variable
export DEBUG=true

# Run agent
cd apps/backend
python run.py --spec 001 --verbose
```

**Debug Output**:
```
[ClientCache] Cache HIT for project index (age: 12.3s / TTL: 300s)
[memory] Memory System Status
[memory] Graphiti configuration
    host=localhost
    port=9999
    database=default
    llm_provider=anthropic
    embedder_provider=openai
[session] Agent Session - coding
[session] Starting agent session
    spec_dir=/project/.auto-claude/specs/001
    phase=coding
    prompt_length=2456
[session] Tool call #1: Read
    tool_input=spec.md
[session] Tool success: Read
    result_length=1234
```

### Common Issues

**Issue**: Agent doesn't update implementation_plan.json

**Solution**: Check post-session processing logs. Memory save happens in Python, not by agent.

**Issue**: Agent gets "pathspec did not match" error

**Solution**: Path confusion - agent changed directory with `cd` and used wrong relative paths. Check `pwd` in logs.

**Issue**: Graphiti context not loading

**Solution**: Check `.env` configuration:
```bash
GRAPHITI_ENABLED=true
ANTHROPIC_API_KEY=sk-ant-...
```

**Issue**: QA Reviewer can't connect to Electron

**Solution**: Ensure Electron MCP is enabled and app is running:
```bash
# .env
ELECTRON_MCP_ENABLED=true
ELECTRON_DEBUG_PORT=9222

# Start app
npm run dev  # Must have --remote-debugging-port=9222
```

### Task Logger

**Location**: `apps/backend/task_logger.py`

**Purpose**: Persistent logging across agent sessions

**Log Location**: `.auto-claude/specs/XXX/logs/session_NNN.jsonl`

**Features**:
- Session-based logs (one file per session)
- Phase tracking (planning, coding, qa)
- Tool call tracking (start, end, success/failure)
- Text message tracking
- Error tracking
- Expandable detail sections (for large tool outputs)

**Usage**:
```python
from task_logger import get_task_logger, LogPhase, LogEntryType

task_logger = get_task_logger(spec_dir)

# Start phase
task_logger.start_phase(LogPhase.CODING, "Starting implementation")

# Log text
task_logger.log("Working on authentication", LogEntryType.TEXT, LogPhase.CODING)

# Track tool usage
task_logger.tool_start("Read", "spec.md", LogPhase.CODING)
task_logger.tool_end("Read", success=True, detail="file contents...", phase=LogPhase.CODING)

# End phase
task_logger.end_phase(LogPhase.CODING, success=True, message="Completed")
```

## Integration with Frontend

The Electron desktop app uses the agent system:

**Frontend → Backend Communication**:

```typescript
// Frontend calls backend Python CLI
import { spawn } from 'child_process';

function runSpec(specId: string) {
  const proc = spawn('python', [
    'apps/backend/run.py',
    '--spec', specId
  ]);

  // Stream logs to UI
  proc.stdout.on('data', (data) => {
    updateUI(data.toString());
  });
}
```

**Live Status Updates**:

**ccstatusline** integration (optional):

```bash
# Enable in .env
CCSTATUSLINE_ENABLED=true

# Agents automatically update status
# File: .auto-claude/ccstatusline.txt
```

**Status File Format**:
```json
{
  "active_spec": "001-authentication",
  "state": "building",
  "phase": "Backend API (2/3)",
  "subtasks": {
    "completed": 5,
    "total": 12,
    "in_progress": 1
  },
  "session": 6
}
```

## Resources

### Key Files

- **Agent Implementations**: `apps/backend/agents/`
- **Agent Prompts**: `apps/backend/prompts/`
- **Tool Configuration**: `apps/backend/agents/tools_pkg/`
- **Client Factory**: `apps/backend/core/client.py`
- **Memory System**: `apps/backend/agents/memory_manager.py`
- **Security**: `apps/backend/core/security.py`
- **Recovery**: `apps/backend/recovery.py`

### Documentation

- **CLAUDE.md**: Project overview and development guidelines
- **RELEASE.md**: Release process and versioning
- **guides/**: Additional documentation

### External Resources

- [Claude Agent SDK Documentation](https://platform.claude.com/docs/agent-sdk)
- [Claude Code Documentation](https://claude.ai/code)
- [Graphiti Memory Documentation](https://github.com/getzep/graphiti)

## Contributing

When contributing new agents:

1. Follow existing agent patterns
2. Add to `AGENT_CONFIGS` in `tools_pkg/models.py`
3. Create prompt in `prompts/`
4. Add comprehensive docstrings
5. Test with multiple project types
6. Document in this file

**Pull Request Checklist**:

- [ ] Agent configuration added to `AGENT_CONFIGS`
- [ ] Agent module created in `agents/`
- [ ] Agent prompt created in `prompts/`
- [ ] CLI integration added to `run.py`
- [ ] Tests added (if applicable)
- [ ] Documentation updated (this file)
- [ ] Tested on all three platforms (Windows, macOS, Linux)

---

**Questions or Issues?**

- Open an issue on GitHub
- Reference this document and CLAUDE.md
- Check agent logs in `.auto-claude/specs/XXX/logs/`
