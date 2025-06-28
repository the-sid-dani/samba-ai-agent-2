# 🚀 SambaAI GKE Deployment Guide

This guide will walk you through deploying SambaAI on Google Kubernetes Engine (GKE) with automated CI/CD. Follow these steps in order.

## 📋 Prerequisites (5 minutes)

### Step 1: Install Required Tools

**Install Google Cloud SDK:**
```bash
# macOS (using Homebrew)
brew install --cask google-cloud-sdk

# Verify installation
gcloud version
```

**Install kubectl:**
```bash
# macOS (using Homebrew)
brew install kubectl

# Verify installation
kubectl version --client
```

### Step 2: Authenticate with Google Cloud
```bash
# Login to Google Cloud
gcloud auth login

# Set your project
gcloud config set project ai-workflows-459123

# Verify authentication
gcloud auth list
```

---

## 🏗️ Phase 1: Initial Infrastructure Setup (15-20 minutes)

### Step 3: Deploy the GKE Infrastructure

**Option A: One-Command Deployment (Recommended)**
```bash
# Navigate to your project directory
cd ~/Desktop/4.\ Coding\ Projects/samba-ai-agent

# Run the complete deployment script
./kubernetes/scripts/deploy-all.sh

# Follow the prompts - it will:
# ✅ Create GKE cluster (5-10 minutes)
# ✅ Set up Cloud SQL & Redis (5-10 minutes)  
# ✅ Create Kubernetes secrets
# ✅ Deploy SambaAI (2-3 minutes)
```

**Option B: Step-by-Step (If you prefer manual control)**
```bash
# 1. Create the GKE cluster
./kubernetes/cluster/create-cluster.sh

# 2. Set up managed databases
./kubernetes/cluster/setup-databases.sh

# 3. Continue to Phase 2 for application deployment
```

### Step 4: Build and Push Docker Images
```bash
# Configure Docker for Google Container Registry
gcloud auth configure-docker

# Build and push API server image
cd sambaai/backend
docker build -t gcr.io/ai-workflows-459123/sambaai-api:latest .
docker push gcr.io/ai-workflows-459123/sambaai-api:latest

# Build and push web server image
cd ../web
docker build -t gcr.io/ai-workflows-459123/sambaai-web:latest .
docker push gcr.io/ai-workflows-459123/sambaai-web:latest

# Return to project root
cd ../..
```

### Step 5: Get Your Application URL
```bash
# Get the LoadBalancer IP address
kubectl get service sambaai-loadbalancer --namespace=sambaai

# Test access (replace IP with your actual IP)
curl http://YOUR_LOADBALANCER_IP
```

🎉 **Your SambaAI should now be accessible!**

---

## 🔄 Phase 2: Set Up Automated CI/CD (10 minutes)

### Step 6: Create GitHub Service Account

**In Google Cloud Console:**
1. Go to [IAM & Admin > Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)
2. Click **"Create Service Account"**
3. Name: `github-actions-sambaai`
4. Grant these roles:
   - `Kubernetes Engine Developer`
   - `Storage Admin` (for Container Registry)
   - `Service Account User`
5. Click **"Create Key"** → **"JSON"**
6. **Download the JSON file** (keep it secure!)

### Step 7: Add GitHub Secrets

**In your GitHub repository:**
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"**
3. Add these secrets:

| Secret Name | Value |
|-------------|--------|
| `GCP_SA_KEY` | Paste the **entire contents** of the JSON file you downloaded |

### Step 8: Test Automated Deployment
```bash
# Make a small change to trigger deployment
echo "# Updated $(date)" >> README.md

# Commit and push to trigger CI/CD
git add .
git commit -m "test: Trigger automated deployment"
git push origin main
```

**Watch the deployment:**
- Go to your GitHub repository → **Actions** tab
- You should see the workflow running
- Deployment takes about 5-10 minutes

---

## 🌐 Phase 3: Production Setup (Optional, 15 minutes)

### Step 9: Set Up Custom Domain (Optional)

**If you have a domain:**
```bash
# Update ingress with your domain
sed -i 's/sambaai.example.com/your-domain.com/g' kubernetes/manifests/ingress.yaml

# Apply the updated ingress
kubectl apply -f kubernetes/manifests/ingress.yaml

# Get the ingress IP
kubectl get ingress sambaai-ingress --namespace=sambaai
```

**Point your domain's DNS:**
- Create an **A record** pointing to the ingress IP
- SSL certificates will be automatically provisioned by Google

### Step 10: Configure Authentication (Optional)

**For Google OAuth setup:**
1. Go to [Google Cloud Console > APIs & Services > Credentials](https://console.cloud.google.com/apis/credentials)
2. Create **OAuth 2.0 Client ID**
3. Add authorized redirect URIs:
   - `http://YOUR_DOMAIN/auth/callback`
   - `http://YOUR_LOADBALANCER_IP/auth/callback`
4. Update the API server configuration with OAuth credentials

---

## ✅ Phase 4: Verification & Testing (5 minutes)

### Step 11: Verify Everything Works

**Check cluster status:**
```bash
# Check all pods are running
kubectl get pods --namespace=sambaai

# Check services
kubectl get services --namespace=sambaai

# Check ingress
kubectl get ingress --namespace=sambaai
```

**Test the application:**
```bash
# Get your access URL
echo "LoadBalancer IP: $(kubectl get service sambaai-loadbalancer --namespace=sambaai -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

# Test API health
curl http://YOUR_IP/api/health

# Test web interface
open http://YOUR_IP
```

**Test automated deployment:**
```bash
# Make a code change
echo "console.log('Deployment test');" >> sambaai/web/src/app/page.tsx

# Push to trigger deployment
git add .
git commit -m "test: Auto-deployment verification"
git push origin main

# Watch it deploy automatically in GitHub Actions
```

---

## 🎯 What You've Accomplished

✅ **Production GKE cluster** with auto-scaling  
✅ **Managed databases** (PostgreSQL + Redis)  
✅ **Automated CI/CD** via GitHub Actions  
✅ **Zero-downtime deployments** with rolling updates  
✅ **SSL certificates** (if using custom domain)  
✅ **Load balancing** and high availability  
✅ **Security best practices** with Workload Identity  

---

## 🛠️ Common Commands for Daily Use

**Deploy manually:**
```bash
kubectl apply -f kubernetes/manifests/
```

**Check deployment status:**
```bash
kubectl rollout status deployment/sambaai-api --namespace=sambaai
kubectl rollout status deployment/sambaai-web --namespace=sambaai
```

**View logs:**
```bash
kubectl logs -f deployment/sambaai-api --namespace=sambaai
kubectl logs -f deployment/sambaai-web --namespace=sambaai
```

**Scale the application:**
```bash
kubectl scale deployment sambaai-api --replicas=3 --namespace=sambaai
kubectl scale deployment sambaai-web --replicas=3 --namespace=sambaai
```

**Rollback a deployment:**
```bash
kubectl rollout undo deployment/sambaai-api --namespace=sambaai
```

---

## 📞 Need Help?

### Troubleshooting Commands:
```bash
# Check pod status
kubectl describe pods --namespace=sambaai

# Check events
kubectl get events --namespace=sambaai --sort-by='.lastTimestamp'

# Check cluster info
kubectl cluster-info

# Check node status
kubectl get nodes
```

### Common Issues:
1. **Images not found**: Make sure you pushed to `gcr.io/ai-workflows-459123/`
2. **Pods pending**: Check if cluster has enough resources
3. **Service not accessible**: Verify LoadBalancer IP is assigned
4. **CI/CD failing**: Check GitHub secrets are correctly set

---

## 🚀 You're Done!

Your SambaAI is now running on production-grade infrastructure with automated deployments. Every time you push code to the `main` branch, it will automatically build, test, and deploy to your GKE cluster with zero downtime!

**Next steps:**
- Monitor your application via Google Cloud Console
- Set up alerting for production issues  
- Configure backup procedures for your databases
- Add staging environment for testing changes

**Enjoy your modern, scalable SambaAI deployment!** 🎉 