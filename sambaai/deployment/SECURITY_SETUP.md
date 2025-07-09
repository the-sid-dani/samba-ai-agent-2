# 🛡️ SambaAI Security Setup Guide

## Overview
This guide walks you through securing your SambaAI deployment for production use.

## ⚠️ Critical Security Requirements

### 1. **Authentication Setup** (Required)
Choose one authentication method:

#### Option A: Google Workspace SSO (Recommended)
```bash
# In your .env file:
AUTH_TYPE=google_oauth
GOOGLE_OAUTH_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET=your-client-secret
```

**Setup Steps:**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing one
3. Enable Google OAuth API
4. Create OAuth 2.0 credentials
5. Add authorized redirect URIs: `https://your-domain.com/auth/callback`

#### Option B: Microsoft Azure AD
```bash
AUTH_TYPE=azure_ad
AZURE_CLIENT_ID=your-azure-client-id
AZURE_CLIENT_SECRET=your-azure-client-secret
AZURE_TENANT_ID=your-tenant-id
```

#### Option C: Basic Authentication (Less Secure)
```bash
AUTH_TYPE=basic
# Admin users will be managed through the web interface
```

### 2. **API Key Management** (Critical)
**Never commit real API keys to git!**

#### For Development:
- Use `.env.local` (add to .gitignore)
- Keep real keys in local environment only

#### For Production (Choose one):

**Option A: GCP Secret Manager** (Recommended)
```bash
# Store secrets in GCP Secret Manager
gcloud secrets create openai-api-key --data-file=openai-key.txt
gcloud secrets create anthropic-api-key --data-file=anthropic-key.txt
```

**Option B: Environment Variables**
```bash
# Set directly in deployment environment
export OPENAI_API_KEY="your-real-key"
export ANTHROPIC_API_KEY="your-real-key"
```

### 3. **SSL/TLS Setup** (Required)
```bash
# Domain configuration
WEB_DOMAIN=https://sambaai.yourcompany.com

# Let's Encrypt setup (automated)
./init-letsencrypt.sh
```

### 4. **Network Security**
Update firewall rules to allow only:
- Port 80 (HTTP - redirects to HTTPS)
- Port 443 (HTTPS)
- Port 22 (SSH - restrict to your IP)

### 5. **Rate Limiting Configuration**
```bash
# Add to .env
API_RATE_LIMIT_PER_USER=60
API_RATE_LIMIT_PER_IP=100
CHAT_RATE_LIMIT_PER_USER=20
```

## 🚀 Quick Setup Checklist

### Before Deployment:
- [ ] Choose authentication method
- [ ] Set up OAuth credentials (if using SSO)
- [ ] Generate secure secrets
- [ ] Configure domain and SSL
- [ ] Set up API key management
- [ ] Configure rate limiting
- [ ] Test authentication flow

### After Deployment:
- [ ] Verify HTTPS is working
- [ ] Test authentication
- [ ] Check rate limiting
- [ ] Monitor logs for security events
- [ ] Set up backup procedures

## 🔐 Secret Generation Commands

```bash
# Generate secure secret key
python3 -c "import secrets; print('SECRET_KEY=' + secrets.token_urlsafe(32))"

# Generate secure database password
python3 -c "import secrets; print('POSTGRES_PASSWORD=' + secrets.token_urlsafe(16))"

# Generate secure Redis password
python3 -c "import secrets; print('REDIS_PASSWORD=' + secrets.token_urlsafe(16))"
```

## 🚨 Security Incident Response

If you suspect a security breach:
1. **Immediately rotate all API keys**
2. **Check access logs** for unauthorized access
3. **Review user permissions**
4. **Update all passwords**
5. **Monitor for unusual activity**

## 📞 Need Help?

For security questions:
1. Check the troubleshooting guide
2. Review the deployment logs
3. Contact your system administrator 