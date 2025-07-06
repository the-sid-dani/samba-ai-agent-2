# SambaAI GKE Deployment - Quick Reference Card

## 🚨 CRITICAL: Application won't start without API keys!

### Deploy API Keys (Do This First!)
```bash
# Export keys
export OPENAI_API_KEY="sk-proj-..."
export GOOGLE_OAUTH_CLIENT_ID="123456.apps.googleusercontent.com"
export GOOGLE_OAUTH_CLIENT_SECRET="GOCSPX-..."

# Deploy
cd kubernetes/scripts && ./create-secrets.sh
kubectl apply -f ../manifests/api-server.yaml
kubectl rollout restart deployment --all -n sambaai
```

### Essential Info
```yaml
Cluster: sambaai-gke-cluster
Project: ai-workflows-459123
Zone: us-central1-c
Namespace: sambaai
External IP: 35.193.50.194
```

### Quick Commands
```bash
# Connect to cluster
gcloud container clusters get-credentials sambaai-gke-cluster --zone us-central1-c

# Check status
kubectl get pods -n sambaai
kubectl logs -f deployment/sambaai-api -n sambaai

# Restart everything
kubectl rollout restart deployment --all -n sambaai

# Check secrets
kubectl get secrets -n sambaai | grep -E "api-keys|oauth"

# Test endpoint
curl http://35.193.50.194/health
```

### Database Connection
```sql
# From pods: localhost:5432
# External: 35.184.205.233
Database: onyxdb
User: postgres
Pass: sambaai2024
```

### If Pods Are Crashing
1. Check API keys: `kubectl get secret llm-api-keys -n sambaai`
2. Check logs: `kubectl logs -f deployment/sambaai-api -n sambaai`
3. Verify env vars: `kubectl exec -it deployment/sambaai-api -n sambaai -- env | grep API`

### Files You Need
- Deploy script: `kubernetes/scripts/create-secrets.sh`
- API manifest: `kubernetes/manifests/api-server.yaml`
- Full guide: `kubernetes/docs/DEPLOYMENT_STATUS_HANDOVER.md`

---
**Remember**: Everything is ready except API keys. Deploy them and you're done! 🚀 