#!/bin/bash

# Deploy SambaAI to GCP VM Script
# Usage: ./deploy-to-vm.sh <VM_IP_ADDRESS>

set -e

VM_IP=$1
INSTANCE_NAME="onyx-sambaai-production"
ZONE="us-central1-c"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

if [ -z "$VM_IP" ]; then
    print_error "Usage: ./deploy-to-vm.sh <VM_IP_ADDRESS>"
    echo "Example: ./deploy-to-vm.sh 34.83.123.45"
    exit 1
fi

echo "🚀 Deploying SambaAI to VM: $VM_IP"
echo "=================================="

print_status "Copying SambaAI code to VM..."

# Create deployment package
print_status "Creating deployment package..."
cd ../../  # Go to project root
tar --exclude-vcs --exclude='node_modules' --exclude='*.log' --exclude='__pycache__' -czf /tmp/sambaai-deploy.tar.gz sambaai/

print_status "Uploading code to VM..."
gcloud compute scp /tmp/sambaai-deploy.tar.gz $INSTANCE_NAME:/tmp/ --zone=$ZONE

print_status "Extracting and setting up on VM..."
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="
    set -e
    echo '📦 Extracting SambaAI...'
    cd /data
    sudo tar -xzf /tmp/sambaai-deploy.tar.gz
    sudo chown -R ubuntu:ubuntu sambaai/
    
    echo '🔧 Setting up environment...'
    cd sambaai/deployment/docker_compose/
    
    echo '🐳 Starting SambaAI services...'
    docker-compose -f docker-compose.prod.yml down || true
    docker-compose -f docker-compose.prod.yml pull
    docker-compose -f docker-compose.prod.yml up -d
    
    echo '⏳ Waiting for services to start...'
    sleep 30
    
    echo '🏥 Checking service health...'
    docker-compose -f docker-compose.prod.yml ps
    
    echo '📊 Service status:'
    docker-compose -f docker-compose.prod.yml logs --tail=10
"

print_status "Deployment complete!"

echo ""
echo "🎉 SambaAI is now running on GCP!"
echo "================================="
echo "🌐 Access your application:"
echo "   http://$VM_IP"
echo ""
echo "📋 Default Admin Account:"
echo "   You'll need to create an admin account on first visit"
echo "   Go to: http://$VM_IP and click 'Sign Up'"
echo ""
echo "🔧 Management Commands:"
echo "   SSH to VM: gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo "   View logs: docker-compose -f docker-compose.prod.yml logs -f"
echo "   Restart:   docker-compose -f docker-compose.prod.yml restart"
echo "   Stop:      docker-compose -f docker-compose.prod.yml stop"
echo ""
echo "📚 Next Steps:"
echo "1. Visit http://$VM_IP and create your admin account"
echo "2. Add your API keys in Admin > Model Settings"
echo "3. Configure your data connectors"
echo "4. Start using SambaAI!"
echo ""
echo "💾 Database Location on VM:"
echo "   PostgreSQL data: /var/lib/docker/volumes/docker_compose_db_volume"
echo "   Vespa index: /var/lib/docker/volumes/docker_compose_vespa_volume"
echo "   All data is on the persistent disk (/data)"

# Clean up
rm -f /tmp/sambaai-deploy.tar.gz 