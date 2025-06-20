# SambaAI Milestone-Based Development Guide
## Practical Implementation with Taskmaster Integration

### Overview: From Fork to Production in 7 Milestones

This guide provides concrete, verifiable milestones that align with the PRD phases and can be tracked through Taskmaster. Each milestone has:
- Clear UI/visual verification points
- Specific Taskmaster tasks
- Acceptance criteria you can check
- No unverified assumptions

---

## Milestone Structure

### Milestone 0: Clean Fork with Branding
**Goal**: Working Onyx fork with SambaAI branding visible in UI

**Taskmaster Tasks**:
```yaml
SAMBA-001: Fork Onyx repository
SAMBA-002: Update UI branding to SambaAI  
SAMBA-003: Replace logo and favicon
SAMBA-004: Configure docker environment
SAMBA-005: Verify all services start
```

**UI Verification Points**:
- [ ] Open http://localhost:3000 - See "SambaAI" not "Onyx"
- [ ] Logo shows SambaAI branding
- [ ] Docker Desktop shows 8 green containers
- [ ] No console errors in browser

**Quick Test**:
```bash
# All services running?
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(api_server|onyxbot_slack|index|relational_db)"

# UI accessible?
curl -s http://localhost:3000 | grep -c "SambaAI"  # Should return > 0
```

---

### Milestone 1: First Connector Working (Confluence)
**Goal**: Confluence documents indexed and searchable via web UI

**Taskmaster Tasks**:
```yaml
SAMBA-006: Configure Confluence credentials
SAMBA-007: Test Confluence authentication
SAMBA-008: Create connector via admin UI
SAMBA-009: Run first sync
SAMBA-010: Verify documents indexed
```

**UI Verification Points**:
- [ ] Admin UI at http://localhost:3000/admin shows login
- [ ] Navigate to Connectors section
- [ ] Confluence connector shows "Active" status
- [ ] Document count > 0 in overview
- [ ] Search box returns Confluence results

**Visual Check**:
```
Admin UI → Connectors → Confluence Connector
Status: ✅ Active
Last Sync: [timestamp]
Documents: 127 indexed
```

---

### Milestone 2: Both Connectors Active
**Goal**: Google Drive + Confluence both syncing documents

**Taskmaster Tasks**:
```yaml
SAMBA-011: Create GCP service account
SAMBA-012: Configure Drive API access
SAMBA-013: Add Drive connector via UI
SAMBA-014: Test Drive sync
SAMBA-015: Verify combined search
```

**UI Verification Points**:
- [ ] Admin UI shows 2 active connectors
- [ ] Drive connector status is green
- [ ] Search results show mixed sources
- [ ] Document sets created for both

**Search Test**:
```
Search UI: "deployment guide"
Results should show:
- 📄 From Confluence: Deployment Guide
- 📄 From Drive: Deploy Process.doc
```

---

### Milestone 3: Slack Bot Responding
**Goal**: @sambaai responds in Slack with search results

**Taskmaster Tasks**:
```yaml
SAMBA-016: Create Slack app at api.slack.com
SAMBA-017: Configure bot tokens in .env
SAMBA-018: Update bot display name
SAMBA-019: Test bot mention response
SAMBA-020: Verify search results in thread
```

**Slack Verification**:
- [ ] Bot appears as @sambaai in workspace
- [ ] Mention @sambaai - get response
- [ ] Response includes document citations
- [ ] Works in channels and DMs

**Test Interaction**:
```
You: @sambaai how do I deploy to production?
Bot: I found several documents about deployment...
     [Shows results from both Confluence and Drive]
     Sources: 
     - Confluence: "Deployment Guide"
     - Drive: "Production Checklist"
```

---

### Milestone 4: Channel Configuration Active
**Goal**: Different Slack channels see different documents

**Taskmaster Tasks**:
```yaml
SAMBA-021: Create document sets in admin UI
SAMBA-022: Map #engineering to eng docs
SAMBA-023: Map #product to product docs
SAMBA-024: Test channel filtering
SAMBA-025: Verify access control
```

**Admin UI Verification**:
- [ ] Document Sets section shows your sets
- [ ] Channel configurations visible
- [ ] Each channel mapped correctly

**Channel Test**:
```
#engineering: @sambaai search deployment
→ Returns only engineering docs

#product: @sambaai search deployment  
→ Returns only product docs
```

---

### Milestone 5: Production Ready
**Goal**: All systems stable, tests passing, monitoring ready

**Taskmaster Tasks**:
```yaml
SAMBA-026: Run integration test suite
SAMBA-027: Performance benchmarking
SAMBA-028: Configure production env
SAMBA-029: Document runbooks
SAMBA-030: Load testing
```

**Test Dashboard** (create simple HTML):
```html
<!-- monitoring/status.html -->
<div id="status-board">
  <h2>SambaAI Status</h2>
  <div class="check">✅ API Health: OK</div>
  <div class="check">✅ Connectors: 2 Active</div>
  <div class="check">✅ Documents: 1,247 indexed</div>
  <div class="check">✅ Response Time: 1.2s avg</div>
  <div class="check">✅ Error Rate: 0.1%</div>
</div>
```

---

### Milestone 6: Deployed to Production
**Goal**: Live system accessible to users

**Taskmaster Tasks**:
```yaml
SAMBA-031: Provision GCP resources
SAMBA-032: Deploy Docker containers
SAMBA-033: Configure DNS
SAMBA-034: SSL certificates
SAMBA-035: Initial user onboarding
```

**Production Verification**:
- [ ] https://sambaai.company.com accessible
- [ ] SSL certificate valid
- [ ] Slack bot working in prod workspace
- [ ] Monitoring dashboard live

---

## Taskmaster Integration

### Creating the Task Structure
```bash
# Parse this guide into Taskmaster
task-master parse-prd .taskmaster/docs/sambaai-milestones.md

# View milestone tasks
task-master list --status=pending

# Track milestone progress
task-master show SAMBA-001  # See specific task details
```

### Task Dependencies Example
```yaml
Milestone 0 Tasks:
  SAMBA-001 → SAMBA-002 → SAMBA-003
                    ↓
              SAMBA-004 → SAMBA-005

Milestone 1 requires: All Milestone 0 complete
Milestone 2 requires: Milestone 1 complete
... and so on
```

### Progress Tracking Commands
```bash
# What's next?
task-master next

# Check milestone status
task-master list | grep "Milestone"

# Update progress
task-master set-status --id=SAMBA-001 --status=done
```

---

## Visual Progress Tracking

### Simple Progress Dashboard
Create `monitoring/progress.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>SambaAI Progress</title>
    <style>
        .milestone { 
            padding: 10px; 
            margin: 5px; 
            border: 2px solid #ccc;
        }
        .complete { background-color: #90EE90; }
        .in-progress { background-color: #FFE4B5; }
        .pending { background-color: #F0F0F0; }
    </style>
</head>
<body>
    <h1>SambaAI Development Progress</h1>
    
    <div class="milestone complete">
        <h3>✅ Milestone 0: Clean Fork</h3>
        <p>UI shows SambaAI branding</p>
    </div>
    
    <div class="milestone in-progress">
        <h3>🔄 Milestone 1: Confluence Connector</h3>
        <p>Setting up authentication...</p>
    </div>
    
    <div class="milestone pending">
        <h3>⏳ Milestone 2: Drive Connector</h3>
        <p>Waiting for Milestone 1</p>
    </div>
    
    <!-- Add remaining milestones -->
</body>
</html>
```

---

## Key Principles

1. **No Unverified Assumptions**: Every step is based on what Onyx actually provides
2. **UI-First Verification**: You can SEE progress in web UI, admin UI, or Slack
3. **Incremental Progress**: Each milestone builds on the previous
4. **Taskmaster Compatible**: All tasks can be tracked and managed
5. **Real Checkpoints**: Not theoretical - actual things you can click and verify

---

## Common Pitfalls to Avoid

❌ **Don't assume API endpoints** - Use Onyx's actual admin UI
❌ **Don't skip connectors** - Bot needs documents to search
❌ **Don't rush to Slack** - Get search working first
❌ **Don't customize early** - Use Onyx defaults initially

✅ **Do use the admin UI** - It's there for a reason
✅ **Do test incrementally** - Verify each milestone
✅ **Do check logs** - `docker-compose logs -f [service]`
✅ **Do celebrate progress** - Each milestone is an achievement!

---

## Quick Reference Card

```bash
# Check current milestone
task-master list --status=in-progress | head -5

# Common URLs
Admin UI:    http://localhost:3000/admin
Search UI:   http://localhost:3000
API Health:  http://localhost:8080/api/health
Vespa:       http://localhost:8081

# Useful commands
docker-compose logs -f onyxbot_slack  # Bot logs
docker-compose logs -f api_server     # API logs
docker ps --format "table {{.Names}}\t{{.Status}}"
```

This guide ensures you always know:
1. What milestone you're on
2. What you can verify in the UI
3. What tasks to complete
4. How to track progress in Taskmaster 

