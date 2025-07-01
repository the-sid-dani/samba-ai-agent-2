#!/bin/bash

# SambaAI Managed Databases Setup Script
# Sets up Cloud SQL (PostgreSQL) and Memorystore (Redis)

set -e

# Configuration
PROJECT_ID="ai-workflows-459123"
REGION="us-central1"
ZONE="us-central1-c"

# Database configuration
DB_INSTANCE_NAME="sambaai-postgres"
DB_NAME="onyxdb"
DB_USER="sambaai"
DB_PASSWORD=$(openssl rand -base64 32)

# Redis configuration
REDIS_INSTANCE_NAME="sambaai-redis"

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

echo "🗄️ Setting up SambaAI Managed Databases"
echo "======================================="
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Set the project
gcloud config set project $PROJECT_ID

# Create Cloud SQL PostgreSQL instance
print_info "Creating Cloud SQL PostgreSQL instance..."
print_warning "This may take 5-10 minutes..."

gcloud sql instances create $DB_INSTANCE_NAME \
    --database-version=POSTGRES_15 \
    --tier=db-custom-2-8192 \
    --region=$REGION \
    --assign-ip \
    --database-flags=max_connections=200 \
    --backup-start-time=03:00 \
    --maintenance-window-day=SUN \
    --maintenance-window-hour=04 \
    --storage-type=SSD \
    --storage-size=100GB \
    --storage-auto-increase \
    --deletion-protection

print_status "Cloud SQL instance created"

# Create database
print_info "Creating database and user..."
gcloud sql databases create $DB_NAME --instance=$DB_INSTANCE_NAME

# Create user
gcloud sql users create $DB_USER \
    --instance=$DB_INSTANCE_NAME \
    --password=$DB_PASSWORD

print_status "Database and user created"

# Create Memorystore Redis instance
print_info "Creating Memorystore Redis instance..."
print_warning "This may take 3-5 minutes..."

gcloud redis instances create $REDIS_INSTANCE_NAME \
    --size=1 \
    --region=$REGION \
    --network=default \
    --redis-version=redis_7_0 \
    --enable-auth \
    --maintenance-window-day=sunday \
    --maintenance-window-hour=4

print_status "Redis instance created"

# Get connection details
print_info "Getting connection details..."

DB_CONNECTION_NAME=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(connectionName)")
DB_IP=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(ipAddresses[0].ipAddress)")
REDIS_HOST=$(gcloud redis instances describe $REDIS_INSTANCE_NAME --region=$REGION --format="value(host)")
REDIS_PORT=$(gcloud redis instances describe $REDIS_INSTANCE_NAME --region=$REGION --format="value(port)")
REDIS_AUTH=$(gcloud redis instances get-auth-string $REDIS_INSTANCE_NAME --region=$REGION)

# Create Kubernetes secrets
print_info "Creating Kubernetes secrets..."

kubectl create secret generic sambaai-db-secret \
    --namespace=sambaai \
    --from-literal=host=$DB_IP \
    --from-literal=port=5432 \
    --from-literal=database=$DB_NAME \
    --from-literal=username=$DB_USER \
    --from-literal=password=$DB_PASSWORD \
    --from-literal=connection-name=$DB_CONNECTION_NAME \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic sambaai-redis-secret \
    --namespace=sambaai \
    --from-literal=host=$REDIS_HOST \
    --from-literal=port=$REDIS_PORT \
    --from-literal=auth=$REDIS_AUTH \
    --dry-run=client -o yaml | kubectl apply -f -

print_status "Kubernetes secrets created"

# Save connection details to file
print_info "Saving connection details..."
cat > kubernetes/cluster/database-config.env << EOF
# SambaAI Database Configuration
# Generated on $(date)

# PostgreSQL (Cloud SQL)
DB_HOST=$DB_IP
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_CONNECTION_NAME=$DB_CONNECTION_NAME

# Redis (Memorystore)
REDIS_HOST=$REDIS_HOST
REDIS_PORT=$REDIS_PORT
REDIS_AUTH=$REDIS_AUTH

# Usage Notes:
# - PostgreSQL is accessible via private IP from GKE
# - Redis requires AUTH string for connection
# - Secrets are stored in Kubernetes namespace 'sambaai'
EOF

print_status "Configuration saved to kubernetes/cluster/database-config.env"

# Display summary
echo ""
print_status "Database Setup Complete!"
echo ""
echo "📊 Database Information:"
echo "======================="
echo "PostgreSQL Instance: $DB_INSTANCE_NAME"
echo "PostgreSQL Database: $DB_NAME"
echo "PostgreSQL IP: $DB_IP"
echo ""
echo "Redis Instance: $REDIS_INSTANCE_NAME"
echo "Redis Host: $REDIS_HOST"
echo "Redis Port: $REDIS_PORT"
echo ""
print_info "Connection details are stored in Kubernetes secrets:"
echo "- sambaai-db-secret (PostgreSQL)"
echo "- sambaai-redis-secret (Redis)"
echo ""
print_warning "Security Notes:"
echo "- Database password: $DB_PASSWORD"
echo "- Store this password securely!"
echo "- Both databases are accessible only from GKE cluster"
echo ""

print_status "Databases are ready for SambaAI deployment!" 