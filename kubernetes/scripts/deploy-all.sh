#!/bin/bash

# SambaAI Complete GKE Deployment Script
# This script provisions everything needed for production SambaAI deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}$1${NC}"
    echo "================================================="
}

# Configuration
PROJECT_ID="ai-workflows-459123"
CLUSTER_NAME="sambaai-gke-cluster"
DOMAIN=${1:-""}

print_header "🚀 SambaAI Complete GKE Deployment"
echo "Project ID: $PROJECT_ID"
echo "Cluster: $CLUSTER_NAME"
if [ -n "$DOMAIN" ]; then
    echo "Domain: $DOMAIN"
else
    print_warning "No domain provided - will use LoadBalancer IP"
fi
echo ""

# Check prerequisites
print_header "🔍 Checking Prerequisites"

if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI not found. Please install Google Cloud SDK"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Please install kubectl"
    exit 1
fi

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 > /dev/null; then
    print_error "No active gcloud authentication. Please run: gcloud auth login"
    exit 1
fi

print_status "Prerequisites check passed"

# Step 1: Create GKE Cluster
print_header "🏗️  Step 1: Creating GKE Cluster"
if gcloud container clusters describe $CLUSTER_NAME --zone=us-central1-c --project=$PROJECT_ID &> /dev/null; then
    print_warning "Cluster $CLUSTER_NAME already exists. Skipping creation."
    gcloud container clusters get-credentials $CLUSTER_NAME --zone=us-central1-c --project=$PROJECT_ID
else
    print_info "Running cluster creation script..."
    cd "$(dirname "$0")/../cluster"
    ./create-cluster.sh
fi

print_status "GKE cluster ready"

# Step 2: Setup Databases
print_header "🗄️  Step 2: Setting up Managed Databases"
if gcloud sql instances describe sambaai-postgres --project=$PROJECT_ID &> /dev/null; then
    print_warning "Database instances already exist. Skipping creation."
else
    print_info "Running database setup script..."
    cd "$(dirname "$0")/../cluster"
    ./setup-databases.sh
fi

print_status "Databases ready"

# Step 3: Create Application Secrets
print_header "🔐 Step 3: Creating Application Secrets"

# Generate secret key if not exists
SECRET_KEY=$(openssl rand -base64 32)

kubectl create secret generic sambaai-app-secret \
    --namespace=sambaai \
    --from-literal=secret-key=$SECRET_KEY \
    --dry-run=client -o yaml | kubectl apply -f -

print_status "Application secrets created"

# Step 4: Build and Push Images (if not using CI/CD)
print_header "🔨 Step 4: Building Container Images"
print_warning "In production, use GitHub Actions CI/CD pipeline"
print_info "For now, you can manually build and push images:"
echo ""
echo "cd sambaai/backend && docker build -t gcr.io/$PROJECT_ID/sambaai-api:latest ."
echo "cd sambaai/web && docker build -t gcr.io/$PROJECT_ID/sambaai-web:latest ."
echo "docker push gcr.io/$PROJECT_ID/sambaai-api:latest"
echo "docker push gcr.io/$PROJECT_ID/sambaai-web:latest"
echo ""
read -p "Have you built and pushed the images? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Please build and push images, then run this script again"
    exit 1
fi

# Step 5: Deploy Application
print_header "🚀 Step 5: Deploying SambaAI Application"

cd "$(dirname "$0")/../manifests"

# Update domain in ingress if provided
if [ -n "$DOMAIN" ]; then
    print_info "Updating ingress with domain: $DOMAIN"
    sed -i.bak "s/sambaai.example.com/$DOMAIN/g" ingress.yaml
fi

# Replace placeholders
sed -i.bak "s/PROJECT_ID/$PROJECT_ID/g" *.yaml
sed -i.bak "s/IMAGE_TAG/latest/g" *.yaml

# Apply manifests
print_info "Applying Kubernetes manifests..."
kubectl apply -f api-server.yaml
kubectl apply -f web-server.yaml
kubectl apply -f ingress.yaml

print_status "Application manifests applied"

# Step 6: Wait for deployment
print_header "⏳ Step 6: Waiting for Deployment"

print_info "Waiting for deployments to be ready..."
kubectl rollout status deployment/sambaai-api --namespace=sambaai --timeout=300s
kubectl rollout status deployment/sambaai-web --namespace=sambaai --timeout=300s

print_status "Deployments ready"

# Step 7: Get access information
print_header "🌐 Step 7: Access Information"

echo "Getting service information..."
kubectl get services --namespace=sambaai

# Get LoadBalancer IP
LOADBALANCER_IP=$(kubectl get service sambaai-loadbalancer --namespace=sambaai -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending...")

echo ""
print_status "SambaAI Deployment Complete!"
echo ""
echo "📊 Access Information:"
echo "====================="
if [ -n "$DOMAIN" ]; then
    echo "🌍 Domain: https://$DOMAIN (after DNS setup)"
fi
echo "🔗 LoadBalancer IP: http://$LOADBALANCER_IP"
echo "📋 Namespace: sambaai"
echo "🎛️  Cluster: $CLUSTER_NAME"
echo ""

print_info "Next Steps:"
echo "1. If using a domain, point DNS to the LoadBalancer IP"
echo "2. Set up GitHub Actions for automated deployments"
echo "3. Configure monitoring and alerting"
echo "4. Set up backup procedures"
echo ""

print_status "SambaAI is ready for production use!" 