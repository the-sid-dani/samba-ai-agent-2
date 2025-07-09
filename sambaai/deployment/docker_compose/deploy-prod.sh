#!/bin/bash

# SambaAI Production Deployment Script
# Based on Onyx Docker Compose setup

set -e

echo "🚀 SambaAI Production Deployment"
echo "================================"

# Check if running from correct directory
if [ ! -f "docker-compose.prod.yml" ]; then
    echo "❌ Error: Please run this script from the sambaai/deployment/docker_compose directory"
    exit 1
fi

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "📝 Creating production .env file from template..."
    cp env.prod.template .env
    echo "✅ Created .env file. Please edit it with your configuration:"
    echo "   - Set WEB_DOMAIN to your actual domain"
    echo "   - Configure authentication (AUTH_TYPE, Google OAuth, etc.)"
    echo "   - Set database passwords"
    echo ""
    echo "📋 Key variables to configure in .env:"
    echo "   WEB_DOMAIN=https://your-domain.com"
    echo "   AUTH_TYPE=google_oauth (or basic/disabled)"
    echo "   GOOGLE_OAUTH_CLIENT_ID=your-client-id"
    echo "   GOOGLE_OAUTH_CLIENT_SECRET=your-client-secret"
    echo "   SECRET=your-random-secret-key"
    echo "   POSTGRES_PASSWORD=secure-password"
    echo ""
    read -p "Press Enter after editing .env file..."
fi

# Check if SSL setup is needed
if [ ! -f ".env.nginx" ]; then
    echo "🔒 SSL/HTTPS Setup"
    echo "Do you want to set up SSL/HTTPS with Let's Encrypt? (y/n)"
    read -r setup_ssl
    
    if [ "$setup_ssl" = "y" ] || [ "$setup_ssl" = "Y" ]; then
        echo "📝 Creating nginx environment file..."
        cp env.nginx.template .env.nginx
        echo "✅ Created .env.nginx file. Please edit it with your domain information."
        echo ""
        read -p "Press Enter after editing .env.nginx file..."
        
        echo "🔧 Setting up Let's Encrypt..."
        chmod +x init-letsencrypt.sh
        ./init-letsencrypt.sh
    fi
fi

echo "🐳 Starting SambaAI production containers..."
echo "This may take several minutes on first run..."

# Pull latest images and start services
docker compose -f docker-compose.prod.yml -p samba-ai-prod up -d --pull always --force-recreate

echo ""
echo "✅ SambaAI is starting up!"
echo ""
echo "📊 Check status: docker compose -f docker-compose.prod.yml -p samba-ai-prod ps"
echo "📋 View logs: docker compose -f docker-compose.prod.yml -p samba-ai-prod logs -f"
echo "🛑 Stop services: docker compose -f docker-compose.prod.yml -p samba-ai-prod stop"
echo "🗑️  Remove services: docker compose -f docker-compose.prod.yml -p samba-ai-prod down"
echo ""

# Wait a moment and show status
sleep 5
echo "Current container status:"
docker compose -f docker-compose.prod.yml -p samba-ai-prod ps

echo ""
echo "🎉 Deployment complete! Your SambaAI instance should be available shortly."
echo "🌐 Access your application at: $(grep WEB_DOMAIN .env | cut -d'=' -f2)" 