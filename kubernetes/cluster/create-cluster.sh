#!/bin/bash

# SambaAI GKE Cluster Creation Script
# Production-ready configuration for SambaAI deployment

set -e

# Configuration
PROJECT_ID="ai-workflows-459123"
CLUSTER_NAME="sambaai-gke-cluster"
REGION="us-central1"
ZONE="us-central1-c"

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

echo "🚀 Creating SambaAI GKE Cluster"
echo "================================"
echo "Project ID: $PROJECT_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "Region: $REGION"
echo ""

# Check if gcloud is configured
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -1 > /dev/null; then
    print_error "No active gcloud authentication found"
    echo "Please run: gcloud auth login"
    exit 1
fi

# Set the project
print_info "Setting project to $PROJECT_ID"
gcloud config set project $PROJECT_ID

# Enable required APIs
print_info "Enabling required Google Cloud APIs..."
gcloud services enable container.googleapis.com \
    compute.googleapis.com \
    sqladmin.googleapis.com \
    redis.googleapis.com \
    cloudbuild.googleapis.com \
    containerregistry.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com

print_status "APIs enabled successfully"

# Create the GKE cluster
print_info "Creating GKE cluster (this may take 5-10 minutes)..."

gcloud container clusters create $CLUSTER_NAME \
    --project=$PROJECT_ID \
    --zone=$ZONE \
    --machine-type=e2-standard-4 \
    --num-nodes=3 \
    --min-nodes=1 \
    --max-nodes=10 \
    --enable-autoscaling \
    --enable-autorepair \
    --enable-autoupgrade \
    --disk-type=pd-ssd \
    --disk-size=100GB \
    --enable-ip-alias \
    --network=default \
    --subnetwork=default \
    --enable-cloud-logging \
    --enable-cloud-monitoring \
    --release-channel=stable \
    --workload-pool=$PROJECT_ID.svc.id.goog \
    --enable-shielded-nodes

print_status "GKE cluster created successfully"

# Get cluster credentials
print_info "Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE --project=$PROJECT_ID

print_status "Cluster credentials configured"

# Create namespace for SambaAI
print_info "Creating namespaces..."
kubectl create namespace sambaai --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

print_status "Namespaces created"

# Create service account for workload identity
print_info "Setting up Workload Identity..."
gcloud iam service-accounts create sambaai-gke \
    --display-name="SambaAI GKE Service Account" \
    --project=$PROJECT_ID || true

# Grant necessary permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:sambaai-gke@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:sambaai-gke@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/redis.editor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:sambaai-gke@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.objectViewer"

# Bind Kubernetes service account to Google service account
kubectl create serviceaccount sambaai-ksa --namespace=sambaai --dry-run=client -o yaml | kubectl apply -f -

gcloud iam service-accounts add-iam-policy-binding \
    sambaai-gke@$PROJECT_ID.iam.gserviceaccount.com \
    --role="roles/iam.workloadIdentityUser" \
    --member="serviceAccount:$PROJECT_ID.svc.id.goog[sambaai/sambaai-ksa]"

kubectl annotate serviceaccount sambaai-ksa \
    --namespace=sambaai \
    iam.gke.io/gcp-service-account=sambaai-gke@$PROJECT_ID.iam.gserviceaccount.com

print_status "Workload Identity configured"

# Display cluster information
print_status "GKE Cluster Setup Complete!"
echo ""
echo "📊 Cluster Information:"
echo "======================"
kubectl get nodes
echo ""
kubectl get namespaces
echo ""

print_info "Next steps:"
echo "1. Set up Cloud SQL and Memorystore"
echo "2. Deploy SambaAI manifests"
echo "3. Configure CI/CD pipeline"
echo ""

print_status "Cluster is ready for SambaAI deployment!" 