#!/bin/bash

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║        🚀 INSTALADOR DE PROJETO V0 / NEXT.JS       ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Verificar se está como root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Por favor, execute como root (use sudo)"
  exit 1
fi

# Perguntas iniciais
read -p "🔗 URL do repositório Git: " GIT_REPO
read -p "🌐 Domínio (ex: meudominio.com): " DOMAIN
read -p "🔢 Porta para a aplicação (ex: 3001): " APP_PORT

# Variáveis derivadas
PROJECT_NAME=$(echo $DOMAIN | cut -d'.' -f1)
PROJECT_PATH="/var/www/$PROJECT_NAME"

# Instalar dependências
apt update -y
apt install -y curl git nginx ufw unzip gnupg2 software-properties-common

# Node.js
if ! command -v node &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt install -y nodejs
fi

# PM2
if ! command -v pm2 &> /dev/null; then
  npm install -g pm2
fi

# Certbot
if ! command -v certbot &> /dev/null; then
  apt install -y certbot python3-certbot-nginx
fi

# Clonar projeto
git clone $GIT_REPO $PROJECT_PATH || { echo "❌ Falha ao clonar repositório"; exit 1; }
cd $PROJECT_PATH

# Configurar .env
echo "PORT=$APP_PORT" > .env

# Instalar dependências
npm install || { echo "❌ Erro ao instalar dependências"; exit 1; }
npm run build || { echo "❌ Falha no build"; exit 1; }

# Iniciar com PM2
pm2 start npm --name "$PROJECT_NAME" -- start
pm2 save
pm2 startup | bash

# Firewall
ufw allow "$APP_PORT"
ufw allow 'Nginx Full'

# Nginx
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"

cat > $NGINX_CONFIG <<EOL
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

ln -s $NGINX_CONFIG /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# HTTPS
certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

echo ""
echo "✅ Instalação concluída!"
echo "🌍 Acesse: https://$DOMAIN"
