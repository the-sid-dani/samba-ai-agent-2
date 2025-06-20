# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SambaAI is a forked version of Onyx (v0.29.1) - an enterprise search and AI chat platform. The project maintains Onyx's core architecture while implementing minimal rebranding and custom configurations for Samba's internal use. The system provides a Slack bot (@sambaai) that searches Confluence and Google Drive documents.

## Architecture Overview

### Dual-Repository Structure
```
samba-ai-agent/                    # Task management repository
├── .taskmaster/                   # Task Master project management
│   ├── tasks/                     # Task tracking (tasks.json)
│   ├── docs/                      # PRD and technical docs
│   └── config.json               # Task Master configuration
└── sambaai/                      # Onyx fork (main codebase)
    ├── backend/                  # Python backend (Onyx package structure)
    ├── web/                      # React frontend
    └── deployment/               # Docker configurations
```

### Core Services Architecture
- **API Server** (port 8080): Main backend API using FastAPI
- **Web Server** (port 3000): Next.js React frontend
- **Background Workers**: Celery workers for document indexing and async tasks
- **PostgreSQL**: Transactional data storage
- **Vespa**: Vector search engine (embeddings & full-text)
- **Redis**: Caching and session management
- **Model Servers**: Local embedding model services
- **Nginx**: Reverse proxy

### Key Technologies
- **Backend**: Python 3.11, FastAPI, SQLAlchemy, Alembic
- **Frontend**: Next.js, React, TypeScript, Tailwind CSS
- **LLM Integration**: LiteLLM (supports Claude, OpenAI, etc.)
- **Embedding Model**: nomic-ai/nomic-embed-text-v1 (self-hosted)
- **Search**: Vespa (hybrid vector + keyword search)

## Development Commands

### Backend Development

```bash
# Setup Python environment (Python 3.11 required)
python -m venv .venv
source .venv/bin/activate

# Install dependencies
cd sambaai/backend
pip install -r requirements/default.txt
pip install -r requirements/dev.txt
pip install -r requirements/ee.txt
pip install -r requirements/model_server.txt

# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run type checking
python -m mypy .

# Run database migrations
alembic upgrade head

# Start backend services
AUTH_TYPE=disabled uvicorn onyx.main:app --reload --port 8080
uvicorn model_server.main:app --reload --port 9000
python ./scripts/dev_run_background_jobs.py
```

### Frontend Development

```bash
cd sambaai/web

# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Lint and format
npm run lint
npx prettier --write .
```

### Docker Development

```bash
cd sambaai/deployment/docker_compose

# Start all services
docker compose -f docker-compose.dev.yml -p onyx-stack up -d

# Start only infrastructure services
docker compose -f docker-compose.dev.yml -p onyx-stack up -d index relational_db cache

# View logs
docker compose -f docker-compose.dev.yml -p onyx-stack logs -f

# Stop services
docker compose -f docker-compose.dev.yml -p onyx-stack down
```

### Testing

```bash
# Backend tests
cd sambaai/backend
pytest

# Run specific test
pytest tests/unit/test_specific.py -v

# Frontend tests
cd sambaai/web
npm test
```

## Critical Implementation Details

### Environment Configuration
Primary configuration file: `sambaai/deployment/docker_compose/.env`

Key environment variables:
- `GEN_AI_MODEL_VERSION`: Main LLM model (e.g., claude-opus-4-20250514)
- `FAST_GEN_AI_MODEL_VERSION`: Fast model for simple queries
- `GEN_AI_API_KEY`: LLM provider API key
- `ANTHROPIC_API_KEY`: Anthropic-specific key (if using Claude)
- Confluence/Google Drive credentials configured via web UI, not .env

### Model Configuration
The system detects Claude models in `sambaai/backend/onyx/setup.py` (lines 309-338) and creates appropriate providers via LiteLLM. This was modified from the original Onyx code that defaulted to OpenAI.

### Slack Bot Configuration

**Architecture Overview:**
- Bot name is dynamically fetched from Slack API (listener.py:475-480)
- Mention detection uses bot user ID, not hardcoded names (listener.py:669-670, 839-841)
- Multi-tenant support with Redis-based coordination
- Socket Mode for real-time event handling

**Bot Name Handling:**
```python
# Dynamic bot name fetching from Slack API
user_info = socket_client.web_client.users_info(user=bot_user_id)
if user_info["ok"]:
    bot_name = user_info["user"]["real_name"] or user_info["user"]["name"]
    socket_client.bot_name = bot_name
```

**Minimal Changes Required for SambaAI:**
1. **User-visible error messages** (only 2 instances):
   - `utils.py:102`: "OnyxBot has reached the message limit" → Use dynamic bot name
   - `utils.py:204`: "There was an error displaying all of the Onyx answers" → Change to generic "answers"

2. **Slack App Configuration**:
   ```yaml
   display_information:
     name: SambaAI
     description: Your AI assistant
   features:
     bot_user:
       display_name: SambaAI
       always_online: true
   ```

**No Code Changes Needed For:**
- Mention detection (@sambaai will work automatically)
- Bot authentication and user ID resolution
- Message threading and response handling
- Channel configuration and permissions

### Document Indexing Flow
1. Connectors fetch documents from sources (Confluence/Google Drive)
2. Documents are chunked (default 512 tokens)
3. Embeddings generated via self-hosted model
4. Stored in Vespa with metadata
5. Background workers handle indexing asynchronously

### Search Architecture
- Hybrid search: keyword + vector (weight modifier: 0.7)
- Top-K chunks: 10 by default
- Vespa schema uses 768-dimensional embeddings
- Document sets and channel mappings configured via admin UI

## Important Files and Locations

### Configuration Files
- `sambaai/deployment/docker_compose/.env` - Main environment configuration
- `sambaai/backend/alembic.ini` - Database migration config
- `sambaai/backend/pyproject.toml` - MyPy configuration
- `.taskmaster/config.json` - Task Master model configuration

### Key Backend Modules
- `sambaai/backend/onyx/setup.py` - Initial setup and LLM provider detection
- `sambaai/backend/onyx/onyxbot/slack/` - Slack bot implementation
  - `listener.py` - Main bot event listener and message handling
  - `utils.py` - Helper functions and bot utilities (contains 2 hardcoded messages)
  - `models.py` - Slack message data models
- `sambaai/backend/onyx/connectors/` - Document source connectors
- `sambaai/backend/onyx/document_index/vespa/` - Search implementation
- `sambaai/backend/onyx/llm/` - LLM integration layer

### Frontend Entry Points
- `sambaai/web/src/app/` - Next.js app directory
- `sambaai/web/src/components/` - React components
- `sambaai/web/package.json` - Frontend dependencies and scripts

## Development Workflow

### Making Changes
1. Keep internal Onyx package names and structure
2. Only change user-visible text and branding
3. Configure through environment variables when possible
4. Use the admin UI for connector and document set configuration

### Adding New Features
1. Follow Onyx's existing patterns and architecture
2. Add abstraction layers for future flexibility
3. Keep database schema compatible with upstream Onyx
4. Document any custom modifications

### Common Tasks

**Adding a new connector:**
1. Create connector in `sambaai/backend/onyx/connectors/`
2. Follow existing connector patterns
3. Configure via admin UI, not hardcoded credentials

**Modifying LLM settings:**
1. Update `.env` file with new model names
2. Ensure `setup.py` properly detects the model provider
3. Test with both main and fast models

**Debugging Slack bot:**
1. Check bot user ID detection in listener.py
2. Verify Socket Mode connection
3. Monitor background worker logs for processing

## Deployment Considerations

### Production Configuration
- Use `docker-compose.prod.yml` for production deployments
- Configure proper resource limits (API: 4GB RAM, Vespa: 8GB RAM)
- Enable HTTPS/TLS for external connections
- Implement proper secret management
- Set up automated backups for PostgreSQL and Vespa data

### Performance Targets
- Query latency: < 3 seconds
- Support 50+ concurrent users
- Handle 100K+ documents
- 99% uptime

## Current Task Context

The project is being developed according to the Task Master system with 30 defined tasks. Key completed milestones:
- Repository forked and Docker services verified
- Environment configuration established  
- LLM provider setup fixed for Claude models
- Database migrations completed
- Slack bot name configuration investigation completed (Task 7)

Key findings from Task 7:
- Bot name is already dynamically configurable via Slack app settings
- Only 2 user-visible error messages need updating for complete rebranding
- Mention detection uses bot IDs, making @sambaai work automatically

Current focus areas per Task Master:
- Confluence connector configuration (Task 8)
- Implementing the 2 error message fixes identified in Task 7
- Creating Slack app with SambaAI branding (Task 13)

## Notes for Future Development

- The embedding model (nomic-ai/nomic-embed-text-v1) is self-hosted to avoid API costs
- Vespa schema changes require full re-indexing
- Channel mappings use Onyx's built-in `slack_channel_config` table
- Document sets can be configured via admin UI at `/admin/bots`
- Keep changes minimal to ease future Onyx version upgrades