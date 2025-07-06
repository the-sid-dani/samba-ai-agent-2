#!/bin/bash

# Create API Keys Secrets Script for SambaAI
# This script creates Kubernetes secrets for all required API keys

set -e

echo "Creating API key secrets for SambaAI..."

# Ensure we're in the sambaai namespace
kubectl create namespace sambaai --dry-run=client -o yaml | kubectl apply -f -

# Create LLM API Keys Secret
echo "Creating LLM API keys secret..."
kubectl create secret generic llm-api-keys \
  --namespace=sambaai \
  --from-literal=OPENAI_API_KEY="${OPENAI_API_KEY}" \
  --from-literal=ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}" \
  --from-literal=GOOGLE_API_KEY="${GOOGLE_API_KEY}" \
  --from-literal=GEMINI_API_KEY="${GEMINI_API_KEY:-${GOOGLE_API_KEY}}" \
  --from-literal=GEN_AI_API_KEY="${GEN_AI_API_KEY:-${OPENAI_API_KEY}}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Google OAuth Secret (for authentication)
echo "Creating Google OAuth secret..."
kubectl create secret generic google-oauth \
  --namespace=sambaai \
  --from-literal=GOOGLE_OAUTH_CLIENT_ID="${GOOGLE_OAUTH_CLIENT_ID}" \
  --from-literal=GOOGLE_OAUTH_CLIENT_SECRET="${GOOGLE_OAUTH_CLIENT_SECRET}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Slack Bot Secret (if using Slack integration)
if [[ -n "${DANSWER_BOT_SLACK_APP_TOKEN}" ]]; then
  echo "Creating Slack bot secret..."
  kubectl create secret generic slack-bot-config \
    --namespace=sambaai \
    --from-literal=DANSWER_BOT_SLACK_APP_TOKEN="${DANSWER_BOT_SLACK_APP_TOKEN}" \
    --from-literal=DANSWER_BOT_SLACK_BOT_TOKEN="${DANSWER_BOT_SLACK_BOT_TOKEN}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# Create Bing API Key Secret (if using web search)
if [[ -n "${BING_API_KEY}" ]]; then
  echo "Creating Bing API key secret..."
  kubectl create secret generic web-search-keys \
    --namespace=sambaai \
    --from-literal=BING_API_KEY="${BING_API_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# Create Langfuse Secret (if using observability)
if [[ -n "${LANGFUSE_SECRET_KEY}" ]]; then
  echo "Creating Langfuse observability secret..."
  kubectl create secret generic langfuse-config \
    --namespace=sambaai \
    --from-literal=LANGFUSE_SECRET_KEY="${LANGFUSE_SECRET_KEY}" \
    --from-literal=LANGFUSE_PUBLIC_KEY="${LANGFUSE_PUBLIC_KEY}" \
    --from-literal=LANGFUSE_HOST="${LANGFUSE_HOST:-https://us.cloud.langfuse.com}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "✅ All secrets created successfully!"
echo ""
echo "To verify secrets were created:"
echo "kubectl get secrets -n sambaai"
echo ""
echo "To view a specific secret (base64 encoded):"
echo "kubectl get secret llm-api-keys -n sambaai -o yaml" 