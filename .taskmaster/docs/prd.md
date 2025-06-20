# SambaAI: Pragmatic Knowledge Retrieval Platform
## Product Requirements Document v3.0

### 1. PROJECT OVERVIEW

**Product Name:** SambaAI  
**Base Platform:** Fork of Onyx v0.29.1  
**Primary Function:** Slack bot providing instant answers from Confluence and Google Drive  
**Target Users:** Samba engineering, product, and support teams  
**Development Philosophy:** Minimal changes, maximum functionality

#### 1.1 Core Principles
- **UI-Only Rebranding**: Keep internal "Onyx" references, change only user-visible elements
- **Use Defaults**: Leverage Onyx's proven architecture and models
- **Build Flexibility**: Add abstraction layers for future customization
- **Pragmatic MVP**: Get working system first, optimize later

#### 1.2 What Changes vs What Stays

**Changes (User-Visible Only)**:
```
✓ Web UI text "Onyx" → "SambaAI"
✓ Slack bot name @onyxbot → @sambaai
✓ Logo and favicon files
✓ Email templates (if any)
✓ User-facing error messages
```

**Stays As-Is (Under the Hood)**:
```
✓ Package names (onyx.*)
✓ Database schemas
✓ Docker service names
✓ Environment variables (DANSWER_*)
✓ API routes (/api/onyx/*)
✓ Internal function names
```

### 2. TECHNICAL FOUNDATION

#### 2.1 Repository Structure
```
sambaai/
├── backend/
│   ├── onyx/                    # Keep package name
│   │   ├── server/              # API endpoints
│   │   ├── onyxbot/slack/       # Slack bot (update display name only)
│   │   ├── connectors/          # Confluence/Drive connectors
│   │   └── document_index/      # Vespa integration
├── web/
│   ├── src/
│   │   └── app/                 # Update UI text only
│   └── public/                  # Replace logos
├── deployment/
│   └── docker_compose/
│       ├── docker-compose.dev.yml
│       └── .env                 # Configuration
└── scripts/                     # Setup utilities
```

#### 2.2 Database Architecture
```yaml
# Three databases, each with specific purpose:
PostgreSQL:           # Transactional data
  - User accounts & auth
  - Connector configs
  - Document metadata
  - Channel mappings
  
Vespa:               # Vector search
  - Document embeddings
  - Full-text indices
  - Chunk storage
  
Redis:               # Caching
  - Query results
  - Session data
  - Rate limiting
```

#### 2.3 Core Services
```yaml
services:
  api_server:        # Port 8080 - Main API
  background:        # Document processing
  onyxbot_slack:     # Slack WebSocket listener
  relational_db:     # PostgreSQL 15.2
  index:             # Vespa 8.277.17
  cache:             # Redis 7.0.15
  model_server:      # Port 9000 - Embeddings
  nginx:             # Port 3000 - Reverse proxy
```

### 3. PHASE 0: REPOSITORY SETUP

#### 3.1 Fork and Minimal Rebrand
**Task:** Fork Onyx, change only user-visible branding

**Changes Required**:
```bash
# Web UI text replacements
web/src/app/**/*.tsx: "Onyx" → "SambaAI"
web/src/components/logo/: Replace logo components

# Logo files
web/public/logo.png → sambaai-logo.png
web/public/favicon.ico → new favicon

# Slack bot display name (investigate first)
backend/onyx/onyxbot/slack/config.py: BOT_NAME = "SambaAI"
```

**NO Changes To**:
- Python imports (`from onyx.server import...`)
- Docker service names
- Database table names
- Environment variable prefixes

**Acceptance Criteria:**
- [ ] Repository forked as `sambaai`
- [ ] UI shows "SambaAI" branding
- [ ] Logos updated
- [ ] Internal code structure unchanged

#### 3.2 Initial Configuration
**Task:** Create base environment configuration

**File:** `deployment/docker_compose/.env`
```env
# Core Settings (Keep Onyx defaults)
AUTH_TYPE=disabled
LOG_LEVEL=info
POSTGRES_PASSWORD=sambaai123
SECRET_KEY=sambaai-secret-key-change-in-prod

# Model Configuration (Use Onyx defaults initially)
GEN_AI_MODEL_PROVIDER=litellm
GEN_AI_MODEL_VERSION=claude-3-sonnet-20240229
FAST_GEN_AI_MODEL_VERSION=claude-3-haiku-20240307
GEN_AI_API_KEY=sk-ant-xxx  # Add real key

# Slack Configuration (Update in Phase 3)
DANSWER_BOT_SLACK_APP_TOKEN=xapp-xxx
DANSWER_BOT_SLACK_BOT_TOKEN=xoxb-xxx

# Future Flexibility (Not used initially)
CUSTOM_BOT_NAME=sambaai
USE_CUSTOM_EMBEDDINGS=false
ALTERNATIVE_VECTOR_STORE=none
```

**Acceptance Criteria:**
- [ ] Docker compose starts successfully
- [ ] All services healthy
- [ ] Can access http://localhost:3000
- [ ] Database migrations complete

### 4. PHASE 1: CONFLUENCE CONNECTOR

#### 4.1 Confluence Authentication
**Task:** Configure existing connector

**Configuration**:
```python
# No code changes needed, just configuration
CONFLUENCE_CONNECTOR_TYPE=confluence  # Keep Onyx type
CONFLUENCE_BASE_URL=https://samba.atlassian.net/wiki
CONFLUENCE_SPACE_KEYS=["ENG", "PRODUCT", "DOCS"]
CONFLUENCE_API_TOKEN=xxx
CONFLUENCE_USER_EMAIL=bot@samba.tv
```

**Acceptance Criteria:**
- [ ] Connector authenticates successfully
- [ ] Can list Confluence spaces
- [ ] Test document indexed
- [ ] Search returns results via web UI

### 5. PHASE 2: GOOGLE DRIVE CONNECTOR

#### 5.1 Service Account Setup
**Task:** Configure Google Drive access

**Requirements**:
- GCP project (free tier)
- Service account with domain delegation
- APIs enabled: Drive, Docs, Sheets

**Configuration**:
```python
GOOGLE_DRIVE_CONNECTOR_TYPE=google_drive
GOOGLE_APPLICATION_CREDENTIALS=/path/to/creds.json
GOOGLE_ADMIN_EMAIL=admin@samba.tv
GOOGLE_DRIVE_FOLDERS=["Engineering", "Product Specs"]
```

**Acceptance Criteria:**
- [ ] Service account created
- [ ] Can list Drive files
- [ ] Documents indexed
- [ ] Permissions respected

### 6. PHASE 3: SLACK BOT CORE

**Prerequisites:** Confluence and Google Drive connectors must be working and have indexed documents before testing the Slack bot.

#### 6.1 Critical Investigation
**Task:** Determine how bot name is configured

**Files to Check**:
```python
backend/onyx/onyxbot/slack/listener.py
backend/onyx/onyxbot/slack/config.py
backend/onyx/onyxbot/slack/utils.py

# Look for:
- Hardcoded "onyxbot" strings
- Bot mention detection logic
- Display name configuration
```

#### 6.2 Slack App Creation
**Task:** Create Slack app with SambaAI branding

**Manifest**:
```yaml
display_information:
  name: SambaAI
  description: Your knowledge assistant
  background_color: "#FF6B6B"
features:
  bot_user:
    display_name: SambaAI      # Critical: must match detection
    always_online: true
oauth_config:
  scopes:
    bot:
      - app_mentions:read
      - channels:history
      - channels:read
      - chat:write
      - groups:history
      - groups:read
      - im:history
      - users:read
settings:
  event_subscriptions:
    bot_events:
      - app_mention            # Key event
      - message.channels
      - message.groups
  socket_mode_enabled: true
```

#### 6.3 Bot Implementation Updates
**Task:** Ensure bot responds to @sambaai

**Potential Changes**:
```python
# If hardcoded, update:
# backend/onyx/onyxbot/slack/listener.py
BOT_NAME = os.getenv("CUSTOM_BOT_NAME", "sambaai")

# Or in mention detection:
if "@sambaai" in event['text'] or f"<@{bot_user_id}>" in event['text']:
    handle_mention(event)
```

**Acceptance Criteria:**
- [ ] Bot responds to @sambaai mentions
- [ ] Works in channels and DMs
- [ ] Thread replies work correctly
- [ ] No "onyxbot" visible to users
- [ ] Can query both Confluence and Drive docs

### 7. PHASE 4: RETRIEVAL & LLM

#### 7.1 Use Onyx Defaults
**Task:** Configure with minimal changes

**Keep Default Settings**:
```python
# backend/onyx/configs/app_configs.py
HYBRID_SEARCH_WEIGHT_MODIFIER = 0.7  # Onyx default
CHUNK_SIZE = 512                     # Onyx default
TOP_K_CHUNKS = 10                    # Onyx default

# Use Onyx's embedding model
DEFAULT_EMBEDDING_MODEL = "all-MiniLM-L6-v2"
```

#### 7.2 Add Flexibility Layer
**Task:** Create abstraction for future changes

**New File:** `backend/onyx/utils/model_flexibility.py`
```python
from abc import ABC, abstractmethod

class EmbeddingProvider(ABC):
    @abstractmethod
    def embed_text(self, text: str) -> List[float]:
        pass

class OnyxDefaultEmbedding(EmbeddingProvider):
    """Current Onyx implementation"""
    def embed_text(self, text: str) -> List[float]:
        # Existing logic
        return embed_with_mini_lm(text)

class FutureCustomEmbedding(EmbeddingProvider):
    """Ready for future Samba models"""
    def embed_text(self, text: str) -> List[float]:
        # Placeholder
        pass

# Factory pattern
def get_embedding_provider() -> EmbeddingProvider:
    if os.getenv("USE_CUSTOM_EMBEDDINGS") == "true":
        return FutureCustomEmbedding()
    return OnyxDefaultEmbedding()
```

**Acceptance Criteria:**
- [ ] Search works with defaults
- [ ] Abstraction layer tested
- [ ] Sub-second query times
- [ ] LLM responses include citations

### 8. PHASE 5: CHANNEL CONFIGURATION

#### 8.1 Use Onyx's Built-in Channel Configuration
**Task:** Configure channel-to-document mappings using existing admin UI

**What Onyx Already Provides Out-of-Box:**
```sql
-- Onyx already has these tables:
slack_bot_config
slack_channel_config (
    id
    slack_channel_id
    slack_channel_name  
    document_sets      -- Which docs this channel can access
    persona_id         -- Which assistant/persona to use
    -- other settings
)
```

**No Custom Development Required!**

#### 8.2 Configuration Steps
**Task:** Set up channel mappings through admin interface

**Configuration Process:**
```bash
# 1. Access Admin UI
http://localhost:3000/admin/bots

# 2. Configure via UI:
- Navigate to Bots → SambaAI Bot → Channels
- Add channel configurations
- Select document sets per channel  
- Choose LLM/persona per channel
```

**Example Configuration Flow:**
```
1. Create Document Sets in Admin UI:
   - "Engineering Docs" → Confluence ENG space + Drive Engineering folder
   - "Product Docs" → Confluence PRODUCT space + Drive Product folder
   - "General Docs" → All document sources

2. Map Slack Channels to Document Sets:
   - #engineering → "Engineering Docs" only
   - #product → "Product Docs" only  
   - #general → "General Docs" (all sources)
   - Unmapped channels → All document sets (default)
```

**What Onyx Handles Automatically:**
- ✅ Channel → Document Set mapping
- ✅ Channel → Persona/LLM selection  
- ✅ Automatic query filtering based on channel
- ✅ Admin UI for configuration management
- ✅ Persistence across restarts

**Acceptance Criteria:**
- [ ] Document sets created via admin UI
- [ ] Channels mapped to appropriate document sets
- [ ] #engineering queries only return engineering docs
- [ ] #product queries only return product docs
- [ ] #general queries return all docs
- [ ] Configuration persists across service restarts
- [ ] Unmapped channels fallback to all documents

### 9. PHASE 6: PRODUCTION PREP

#### 9.1 Docker Optimization
**Task:** Production-ready configuration

**File:** `deployment/docker_compose/docker-compose.prod.yml`
```yaml
version: '3.8'

services:
  api_server:
    image: sambaai/api:${VERSION:-latest}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
    environment:
      - PRODUCTION=true
      - LOG_LEVEL=info
    volumes:
      - api_logs:/logs

  # Vespa needs resources
  index:
    image: vespaengine/vespa:8.277.17
    deploy:
      resources:
        limits:
          memory: 8G
          cpus: '4.0'
    volumes:
      - vespa_data:/opt/vespa/var

volumes:
  api_logs:
  vespa_data:
```

#### 9.2 Future Observability (Langfuse)
**Preparation Only**:
```yaml
# Commented out for future
# langfuse:
#   image: ghcr.io/langfuse/langfuse:latest
#   environment:
#     - DATABASE_URL=postgresql://postgres:password@relational_db:5432/langfuse
#   ports:
#     - "3001:3000"
```

### 10. PHASE 7: GCP DEPLOYMENT

#### 10.1 Simple VM Deployment First
**Task:** Single VM deployment

**Approach**:
```bash
# Single e2-standard-8 VM
- 8 vCPUs, 32GB RAM
- 500GB SSD
- Docker pre-installed
- Static IP assigned

# All services in Docker Compose
- Same as local but with production settings
- Data volumes for persistence
- Automated backups
```

#### 10.2 Future: Managed Services
**Preparation**:
```hcl
# Future terraform modules
# - Cloud SQL for PostgreSQL
# - Memorystore for Redis
# - GKE for container orchestration
# Keep Vespa self-hosted (no managed option)
```

### 11. NON-FUNCTIONAL REQUIREMENTS

#### 11.1 Performance Targets
- Query latency: < 3 seconds (MVP), < 2 seconds (Production)
- Concurrent users: 50 (MVP), 200 (Production)
- Index capacity: 100K documents (MVP), 1M (Production)

#### 11.2 Flexibility Requirements
- Model swapping without code changes
- Vector store abstraction ready
- Observability hooks in place
- Configuration-driven behavior

### 12. TESTING REQUIREMENTS

#### 12.1 MVP Testing
```bash
# Essential tests only
- [ ] Bot responds to mentions
- [ ] Confluence sync works
- [ ] Drive sync works
- [ ] Search returns results
- [ ] Citations included
```

#### 12.2 Integration Tests
```python
# tests/integration/test_minimal_functionality.py
def test_bot_responds_to_sambaai():
    """Ensure rebranding works"""
    response = send_slack_mention("@sambaai hello")
    assert "SambaAI" in response
    assert "onyxbot" not in response

def test_confluence_search():
    """Ensure search works with defaults"""
    results = search("deployment guide")
    assert len(results) > 0
    assert results[0].source_type == "confluence"
```

### 13. DOCUMENTATION REQUIREMENTS

#### 13.1 Setup Guide
```markdown
# SambaAI Quick Start

1. Clone repo
2. Copy .env.example to .env
3. Add API keys
4. docker-compose up -d
5. Create Slack app
6. Test with @sambaai hello
```

#### 13.2 Customization Guide
```markdown
# Future Customizations

## Changing Embedding Models
1. Set USE_CUSTOM_EMBEDDINGS=true
2. Implement CustomEmbedding class
3. Restart services

## Adding Observability
1. Uncomment Langfuse in docker-compose
2. Add @observe decorators
3. View traces at localhost:3001
```

### 14. SUCCESS CRITERIA

#### 14.1 MVP Success
- [ ] @sambaai responds in Slack
- [ ] Searches return relevant results
- [ ] No "Onyx" visible to users
- [ ] All services stable

#### 14.2 Production Success
- [ ] 99% uptime
- [ ] < 3 second response time
- [ ] 100+ daily queries
- [ ] Flexibility layers tested

### 15. RISK MITIGATION

| Risk | Impact | Mitigation | Status |
|------|--------|------------|---------|
| Bot name hardcoded | High | Investigate in Phase 3 | Pending |
| Vespa tightly coupled | Medium | Document schema, don't modify | Planned |
| Model changes break search | Low | Use defaults initially | Mitigated |
| Langfuse integration complex | Low | Defer to Phase 8 | Deferred |

### 16. APPENDIX: KEY DECISIONS

#### A. Why Minimal Rebranding?
- Reduces risk of breaking changes
- Leverages Onyx's proven architecture
- Allows focus on functionality over cosmetics
- Easier to maintain and upgrade

#### B. Why Keep Three Databases?
- PostgreSQL: ACID compliance for critical data
- Vespa: Purpose-built for vector search
- Redis: Proven caching layer
- Removing any would require significant refactoring

#### C. Why Use Onyx's Built-in Channel Config?
- Onyx already has `slack_channel_config` table and admin UI
- No custom development needed for Phase 5
- Proven functionality with proper permissions handling
- Reduces implementation risk and timeline
- Focus development time on core functionality

#### D. Future Enhancement Path
1. **Phase 8**: Langfuse observability
2. **Phase 9**: Custom embedding models
3. **Phase 10**: Alternative vector stores
4. **Phase 11**: Multi-tenant support

---

This PRD reflects our pragmatic approach: minimal changes for maximum functionality, with clear paths for future enhancements when needed.