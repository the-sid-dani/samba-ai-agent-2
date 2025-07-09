#!/bin/bash

# SambaAI GCP Deployment Script
# Deploys SambaAI to Google Cloud Platform

set -e

echo "🚀 SambaAI GCP Deployment Starting..."
echo "====================================="

# Configuration
PROJECT_ID="ai-workflows-459123"
REGION="us-central1"
ZONE="us-central1-c"
INSTANCE_NAME="onyx-sambaai-production"
MACHINE_TYPE="e2-standard-8"
DISK_SIZE="100GB"
BOOT_DISK_SIZE="50GB"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed. Please install it first:"
    echo "https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if project ID is set
if [ "$PROJECT_ID" = "__REPLACE_WITH_PROJECT_ID__" ]; then
    print_error "Please set your PROJECT_ID in this script first!"
    echo "Edit this file and replace __REPLACE_WITH_PROJECT_ID__ with your actual project ID"
    exit 1
fi

print_status "Setting up GCP project: $PROJECT_ID"
gcloud config set project $PROJECT_ID

print_status "Enabling required APIs..."
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com

print_status "Creating VM instance: $INSTANCE_NAME"
gcloud compute instances create $INSTANCE_NAME \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE \
    --boot-disk-size=$BOOT_DISK_SIZE \
    --boot-disk-type=pd-standard \
    --boot-disk-device-name=$INSTANCE_NAME \
    --image-family=ubuntu-2004-lts \
    --image-project=ubuntu-os-cloud \
    --disk=name=${INSTANCE_NAME}-data,size=${DISK_SIZE},type=pd-standard,auto-delete=no \
    --tags=http-server,https-server \
    --metadata=startup-script='#!/bin/bash
        # Update system
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

        # Install Docker
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

        # Install Docker Compose standalone
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose

        # Add ubuntu user to docker group
        usermod -aG docker ubuntu

        # Mount data disk
        mkfs.ext4 -F /dev/sdb
        mkdir -p /data
        mount /dev/sdb /data
        echo "/dev/sdb /data ext4 defaults 0 0" >> /etc/fstab

        # Set up directories
        mkdir -p /data/sambaai
        chown ubuntu:ubuntu /data/sambaai

        echo "VM setup complete" > /tmp/startup-complete
    '

print_status "Configuring firewall rules..."
gcloud compute firewall-rules create sambaai-http --allow tcp:80 --source-ranges 0.0.0.0/0 --target-tags http-server --description "Allow HTTP traffic to SambaAI" || true
gcloud compute firewall-rules create sambaai-https --allow tcp:443 --source-ranges 0.0.0.0/0 --target-tags https-server --description "Allow HTTPS traffic to SambaAI" || true

print_status "Getting external IP address..."
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

print_status "Waiting for VM to be ready..."
echo "This may take 2-3 minutes while Docker is being installed..."

# Wait for startup script to complete
while true; do
    if gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command="test -f /tmp/startup-complete" --quiet 2>/dev/null; then
        break
    fi
    echo "Still setting up VM... (waiting for Docker installation)"
    sleep 30
done

print_status "VM is ready! External IP: $EXTERNAL_IP"

echo ""
echo "🎉 GCP Infrastructure Created Successfully!"
echo "=========================================="
echo "Instance Name: $INSTANCE_NAME"
echo "External IP: $EXTERNAL_IP"
echo "Zone: $ZONE"
echo "Machine Type: $MACHINE_TYPE"
echo ""
echo "🔗 Auto-generated URLs:"
echo "HTTP:  http://$EXTERNAL_IP"
echo "HTTPS: https://$EXTERNAL_IP (after SSL setup)"
echo ""
echo "📋 Next Steps:"
echo "1. Copy your SambaAI code to the VM"
echo "2. Run the deployment"
echo "3. Access your application at http://$EXTERNAL_IP"
echo ""
echo "🚀 Run the deployment script:"
echo "   ./deploy-to-vm.sh $EXTERNAL_IP" 