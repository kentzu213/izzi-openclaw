#!/bin/bash
# ============================================================
# Izzi API Backend — VPS Deploy Script
# Chạy 1 lần trên VPS mới (Ubuntu 22.04/24.04)
# Usage: bash deploy.sh
# ============================================================

set -e

echo "🚀 Izzi API Backend — Deploy Script"
echo "======================================"

# 1. Update system
echo "📦 Updating system..."
apt update && apt upgrade -y

# 2. Install Docker
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    echo "✅ Docker installed"
else
    echo "✅ Docker already installed"
fi

# 3. Install docker-compose plugin
echo "📦 Installing Docker Compose..."
apt install -y docker-compose-plugin 2>/dev/null || true

# 4. Start Redis
echo "🔴 Starting Redis..."
docker rm -f redis 2>/dev/null || true
docker run -d \
  --name redis \
  --restart always \
  -p 127.0.0.1:6379:6379 \
  redis:alpine
echo "✅ Redis running"

# 5. Build and run backend
echo "🏗️ Building Izzi Backend..."
cd /root/izzi-backend

# Build Docker image
docker build -t izzi-backend .

# Stop old container if exists
docker rm -f izzi-backend 2>/dev/null || true

# Run new container
docker run -d \
  --name izzi-backend \
  --restart always \
  --network host \
  --env-file .env \
  izzi-backend

echo "✅ Backend running on port 8787"

# 5b. Start 9Router (universal AI proxy fallback)
echo "🔄 Starting 9Router (AI proxy fallback)..."
docker rm -f ninerouter 2>/dev/null || true
docker run -d \
  --name ninerouter \
  --restart always \
  -p 127.0.0.1:20128:20128 \
  -e OPENROUTER_API_KEY=${OPENROUTER_API_KEYS:-""} \
  ghcr.io/9router/9router:latest 2>/dev/null || {
    echo "⚠️ 9Router Docker image not found, trying npm..."
    npm install -g 9router 2>/dev/null || true
  }
echo "✅ 9Router running on port 20128"

# 6. Install Caddy (reverse proxy + auto HTTPS)
echo "🔒 Installing Caddy (auto HTTPS)..."
if ! command -v caddy &> /dev/null; then
    apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    apt update
    apt install -y caddy
fi

# Configure Caddy with 180s timeout for long AI responses
cat > /etc/caddy/Caddyfile << 'EOF'
api.izziapi.com {
    reverse_proxy localhost:8787 {
        transport http {
            read_timeout 180s
            write_timeout 180s
            dial_timeout 10s
        }
        flush_interval -1
    }
    
    header {
        Access-Control-Allow-Origin https://izziapi.com
        Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
        Access-Control-Allow-Headers "Content-Type, Authorization, X-API-Key"
        Access-Control-Max-Age 86400
    }
}
EOF

systemctl restart caddy
systemctl enable caddy

echo "✅ Caddy configured with auto HTTPS + 180s timeout for api.izziapi.com"

# 7. Firewall
echo "🔥 Configuring firewall..."
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP (Caddy redirect)
ufw allow 443/tcp  # HTTPS (Caddy)
ufw --force enable

echo ""
echo "======================================"
echo "🎉 Deploy complete!"
echo ""
echo "📋 Checklist:"
echo "  1. Trỏ DNS: api.izziapi.com → $(curl -s ifconfig.me)"
echo "  2. Test: curl https://api.izziapi.com/health"
echo "  3. Config SePay webhook: https://api.izziapi.com/api/payment/webhook/vietqr"
echo "======================================"
