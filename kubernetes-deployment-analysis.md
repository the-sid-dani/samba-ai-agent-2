# 🚨 Kubernetes Deployment Issue Analysis

## **Root Cause: Missing Application Code**

The Kubernetes deployment is failing because the **`sambaai/` directory is empty** - it should contain the forked Onyx repository with the actual application code.

## **Current State Analysis**

### ✅ **What's Working**
- **Kubernetes manifests** are properly configured in `kubernetes/manifests/`
- **Deployment scripts** are well-structured in `kubernetes/scripts/`
- **GitHub Actions CI/CD** pipeline is configured in `.github/workflows/deploy-to-gke.yml`
- **Project structure** rules are clearly defined
- **GKE cluster configuration** looks production-ready

### ❌ **Critical Issues Identified**

#### 1. **Missing Application Code (Primary Issue)**
```bash
sambaai/                     # 🔥 Should contain Onyx fork
├── backend/                 # ❌ MISSING - Python backend code
├── web/                     # ❌ MISSING - React frontend
├── deployment/              # ❌ MISSING - Docker configs
└── .git/                    # ❌ MISSING - Onyx fork repository
```

#### 2. **Missing Docker Images**
- The Kubernetes manifests reference images that don't exist:
  - `onyxdotapp/onyx-backend:latest` 
  - `onyxdotapp/onyx-web-server:latest`
- GitHub Actions tries to build from non-existent directories

#### 3. **Missing Environment Configuration**
- Expected location: `sambaai/deployment/docker_compose/.env`
- Current status: Directory doesn't exist

#### 4. **Missing Prerequisites**
- No kubectl installed in current environment
- No gcloud CLI available
- No Docker available for building images

## **Detailed Issue Breakdown**

### **Kubernetes Manifest Issues**

**API Server Deployment (`kubernetes/manifests/api-server.yaml`):**
```yaml
# ❌ ISSUE: Using upstream Onyx images instead of custom SambaAI images
image: onyxdotapp/onyx-backend:latest

# ❌ ISSUE: References secrets that may not exist
secretKeyRef:
  name: postgres-secret  # Needs to be created
  name: redis-secret     # Needs to be created
  name: app-secrets      # Needs to be created
```

**Web Server Deployment (`kubernetes/manifests/web-server.yaml`):**
```yaml
# ❌ ISSUE: Using upstream Onyx images
image: onyxdotapp/onyx-web-server:latest

# ❌ ISSUE: API URL configuration may be incorrect
env:
- name: NEXT_PUBLIC_API_URL
  value: "http://sambaai-api-service.sambaai.svc.cluster.local"
```

**GitHub Actions Workflow Issues:**
```yaml
# ❌ ISSUE: Trying to build from non-existent directories
- name: Build and Push API Server
  run: |-
    cd sambaai/backend  # Directory doesn't exist
    docker build -t "$REGISTRY/$PROJECT_ID/sambaai-api:$GITHUB_SHA" .
```

## **Solutions & Action Plan**

### **Phase 1: Set Up Application Code (CRITICAL)**

#### **Option A: Clone/Fork Onyx Repository**
```bash
# Remove empty sambaai directory
rmdir sambaai/

# Clone the Onyx repository as a submodule or direct clone
git clone https://github.com/onyx-dot-app/onyx.git sambaai
cd sambaai
git remote add upstream https://github.com/onyx-dot-app/onyx.git
git remote set-url origin YOUR_SAMBAAI_FORK_URL

# Or add as submodule
git submodule add https://github.com/YOUR_ORG/sambaai-onyx-fork.git sambaai
```

#### **Option B: Initialize Onyx Fork Structure**
```bash
# Create the expected directory structure
mkdir -p sambaai/{backend,web,deployment/docker_compose}
cd sambaai

# Initialize as separate git repository
git init
git remote add upstream https://github.com/onyx-dot-app/onyx.git
git remote add origin YOUR_SAMBAAI_FORK_URL

# Pull Onyx code
git pull upstream main
```

### **Phase 2: Fix Docker Images**

#### **Update Kubernetes Manifests**
```yaml
# In api-server.yaml, change:
image: onyxdotapp/onyx-backend:latest
# To:
image: gcr.io/ai-workflows-459123/sambaai-api:latest

# In web-server.yaml, change:
image: onyxdotapp/onyx-web-server:latest  
# To:
image: gcr.io/ai-workflows-459123/sambaai-web:latest
```

#### **Create Dockerfiles**
The Onyx repository should have Dockerfiles, but they may need customization for SambaAI branding.

### **Phase 3: Set Up Environment Configuration**

#### **Create Environment File**
```bash
# Create the expected environment file location
mkdir -p sambaai/deployment/docker_compose
touch sambaai/deployment/docker_compose/.env
```

#### **Configure Required Secrets**
```bash
# Create Kubernetes secrets (after setting up the code)
kubectl create namespace sambaai

# Database secrets
kubectl create secret generic postgres-secret \
  --from-literal=host=YOUR_POSTGRES_HOST \
  --from-literal=port=5432 \
  --from-literal=database=sambaai \
  --from-literal=username=sambaai \
  --from-literal=password=YOUR_PASSWORD \
  --namespace=sambaai

# Redis secrets  
kubectl create secret generic redis-secret \
  --from-literal=host=YOUR_REDIS_HOST \
  --from-literal=port=6379 \
  --namespace=sambaai

# Application secrets
kubectl create secret generic app-secrets \
  --from-literal=secret_key=$(openssl rand -base64 32) \
  --namespace=sambaai
```

### **Phase 4: Install Prerequisites**

#### **Install Required Tools**
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

### **Phase 5: Fix Deployment Process**

#### **Update GitHub Actions Workflow**
The workflow should work once the application code is in place, but may need:
- Correct image tags
- Proper secret references
- Updated build contexts

#### **Test Local Deployment**
```bash
# After setting up the code, test locally:
cd sambaai/deployment/docker_compose
docker-compose up -d

# Then test Kubernetes deployment:
cd ../../../kubernetes/scripts
./deploy-all.sh
```

## **Immediate Next Steps**

1. **🔥 CRITICAL: Set up the Onyx fork in `sambaai/` directory**
2. **Create proper Docker images for SambaAI**
3. **Configure environment variables and secrets**
4. **Install kubectl and gcloud CLI tools**
5. **Test the deployment pipeline**

## **Verification Checklist**

- [ ] `sambaai/` directory contains Onyx fork code
- [ ] `sambaai/backend/` has Python backend code
- [ ] `sambaai/web/` has React frontend code  
- [ ] `sambaai/deployment/docker_compose/.env` exists
- [ ] Docker images build successfully
- [ ] Kubernetes secrets are created
- [ ] kubectl and gcloud are installed and configured
- [ ] GKE cluster exists and is accessible
- [ ] GitHub Actions can build and deploy

## **Resources**

- **Onyx Repository**: https://github.com/onyx-dot-app/onyx
- **GKE Documentation**: https://cloud.google.com/kubernetes-engine/docs
- **Project Structure Rules**: `.cursor/rules/project-structure.mdc`
- **Deployment Guide**: `DEPLOYMENT_GUIDE.md`

---

**Priority**: 🚨 **CRITICAL** - The deployment cannot work without the application code in place.