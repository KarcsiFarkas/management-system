#!/bin/bash
# Quick fix for Homepage configuration

set -e

echo "🔧 Fixing Homepage configuration..."
echo ""


# 2. Fix permissions
echo "✓ Setting permissions..."
sudo chown -R 1000:1000 configs/homepage/ 2>/dev/null || chown -R 1000:1000 configs/homepage/

# 3. Update docker-compose.yml to add HOMEPAGE_ALLOWED_HOSTS
echo "✓ Updating docker-compose.yml..."
if ! grep -q "HOMEPAGE_ALLOWED_HOSTS" docker-compose.yml; then
    # Find the homepage environment section and add the variable
    sed -i '/homepage:/,/environment:/ {
        /PGID:/a\      HOMEPAGE_ALLOWED_HOSTS: "localhost,home.localhost,${DOMAIN}"
    }' docker-compose.yml
    echo "  Added HOMEPAGE_ALLOWED_HOSTS to docker-compose.yml"
else
    echo "  HOMEPAGE_ALLOWED_HOSTS already configured"
fi

# 4. Restart Homepage
echo "✓ Restarting Homepage..."
docker compose restart homepage

echo ""
echo "✅ Homepage configuration fixed!"
echo ""
echo "Waiting 10 seconds for Homepage to start..."
sleep 10

echo ""
echo "📊 Checking Homepage status..."
docker compose ps homepage

echo ""
echo "🌐 Access your dashboard:"
echo "  http://localhost"
echo "  http://home.localhost"
echo ""
echo "Check logs with:"
echo "  docker compose logs homepage -f"
echo ""