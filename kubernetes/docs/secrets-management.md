# SambaAI Kubernetes Secrets Management Guide

## Overview
This guide explains how to configure API keys and secrets for your SambaAI deployment on Google Kubernetes Engine (GKE).

## Required API Keys

### Core LLM API Keys (at least one required)
- **OPENAI_API_KEY**: For GPT models (starts with `sk-proj-` or `sk-`)
- **ANTHROPIC_API_KEY**: For Claude models (starts with `sk-ant-`)
- **GOOGLE_API_KEY**: For Gemini models (starts with `AIza`)

### Authentication
- **GOOGLE_OAUTH_CLIENT_ID**: OAuth client ID for Google login
- **GOOGLE_OAUTH_CLIENT_SECRET**: OAuth client secret

### Optional Services
- **BING_API_KEY**: For web search functionality
- **DANSWER_BOT_SLACK_APP_TOKEN**: Slack app token (starts with `xapp-`)
- **DANSWER_BOT_SLACK_BOT_TOKEN**: Slack bot token (starts with `xoxb-`)

## Method 1: Manual Creation (Quick Start)

### 1. Export your API keys as environment variables:
```bash
export OPENAI_API_KEY="sk-proj-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export GOOGLE_API_KEY="AIza..."
export GOOGLE_OAUTH_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export GOOGLE_OAUTH_CLIENT_SECRET="your-client-secret"
```

### 2. Run the secrets creation script:
```bash
cd kubernetes/scripts
chmod +x create-secrets.sh
./create-secrets.sh
```

### 3. Apply the updated deployment:
```bash
kubectl apply -f kubernetes/manifests/api-server.yaml
```

## Method 2: Using Google Secret Manager (Production Recommended)

### 1. Create secrets in Google Secret Manager:
```bash
# Create secrets in GCP
echo -n "sk-proj-..." | gcloud secrets create sambaai-openai-key --data-file=-
echo -n "sk-ant-..." | gcloud secrets create sambaai-anthropic-key --data-file=-
echo -n "AIza..." | gcloud secrets create sambaai-google-key --data-file=-
```

### 2. Use External Secrets Operator:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: gcpsm
  namespace: sambaai
spec:
  provider:
    gcpsm:
      projectID: "ai-workflows-459123"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: llm-api-keys
  namespace: sambaai
spec:
  secretStoreRef:
    name: gcpsm
    kind: SecretStore
  target:
    name: llm-api-keys
  data:
  - secretKey: OPENAI_API_KEY
    remoteRef:
      key: sambaai-openai-key
  - secretKey: ANTHROPIC_API_KEY
    remoteRef:
      key: sambaai-anthropic-key
  - secretKey: GOOGLE_API_KEY
    remoteRef:
      key: sambaai-google-key
```

## Method 3: From GitHub Actions (CI/CD)

If you have secrets in GitHub Actions, create a deployment workflow:

```yaml
# .github/workflows/deploy-secrets.yml
name: Deploy Secrets to GKE
on:
  workflow_dispatch:

jobs:
  deploy-secrets:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v1
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    
    - name: Setup gcloud
      uses: google-github-actions/setup-gcloud@v1
      with:
        install_components: 'gke-gcloud-auth-plugin'
    
    - name: Get GKE credentials
      run: |
        gcloud container clusters get-credentials sambaai-gke-cluster \
          --zone us-central1-c --project ai-workflows-459123
    
    - name: Create Kubernetes secrets
      env:
        OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        GOOGLE_API_KEY: ${{ secrets.GOOGLE_API_KEY }}
        GOOGLE_OAUTH_CLIENT_ID: ${{ secrets.GOOGLE_OAUTH_CLIENT_ID }}
        GOOGLE_OAUTH_CLIENT_SECRET: ${{ secrets.GOOGLE_OAUTH_CLIENT_SECRET }}
      run: |
        cd kubernetes/scripts
        chmod +x create-secrets.sh
        ./create-secrets.sh
```

## Verifying Secrets

### Check if secrets were created:
```bash
kubectl get secrets -n sambaai
```

### View secret details (base64 encoded):
```bash
kubectl describe secret llm-api-keys -n sambaai
```

### Test if API is receiving the keys:
```bash
# Check pod environment variables
kubectl exec -it deployment/sambaai-api -n sambaai -- env | grep API_KEY
```

## Troubleshooting

### Issue: API pods crashing with "Missing API key"
**Solution**: Ensure at least one LLM API key is configured:
```bash
kubectl logs deployment/sambaai-api -n sambaai | grep -i "api"
```

### Issue: OAuth not working
**Solution**: Verify OAuth credentials:
```bash
kubectl get secret google-oauth -n sambaai -o jsonpath='{.data.GOOGLE_OAUTH_CLIENT_ID}' | base64 -d
```

### Issue: Secrets not updating
**Solution**: Restart the deployment after creating/updating secrets:
```bash
kubectl rollout restart deployment/sambaai-api -n sambaai
```

## Security Best Practices

1. **Never commit API keys** to version control
2. **Use least privilege**: Only grant access to required services
3. **Rotate keys regularly**: Update secrets quarterly
4. **Monitor usage**: Set up alerts for unusual API usage
5. **Use Secret Manager**: For production, use Google Secret Manager
6. **Audit access**: Review who has access to secrets

## Quick Reference Commands

```bash
# Create all secrets from environment variables
./kubernetes/scripts/create-secrets.sh

# Update a single secret
kubectl create secret generic llm-api-keys \
  --from-literal=OPENAI_API_KEY="new-key" \
  --namespace=sambaai \
  --dry-run=client -o yaml | kubectl apply -f -

# Delete and recreate a secret
kubectl delete secret llm-api-keys -n sambaai
./kubernetes/scripts/create-secrets.sh

# View all secrets
kubectl get secrets -n sambaai

# Restart API to pick up new secrets
kubectl rollout restart deployment/sambaai-api -n sambaai
``` 