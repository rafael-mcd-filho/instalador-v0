#!/bin/bash

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║        🚀 INSTALADOR DE PROJETO V0 / NEXT.JS       ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Verificar root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Por favor, execute como root (use sudo)"
  exit 1
fi

# Captura da URL do repositório
read -p "🔗 URL do repositório Git: " GIT_REPO

# Loop para domínio válido
while true; do
  read -p "🌐 Domínio (ex: meudominio.com): " DOMAIN
  if [ -f "/etc/nginx/sites-available/$DOMAIN" ]; then
    echo "⚠️ Já existe uma configuração Nginx para $DOMAIN."
    read -p "Deseja informar outro domínio? (s/n): " RESPOSTA
    if [[ "$RESPOSTA" == "s" || "$RESPOSTA" == "S" ]]; then
      continue
    else
      echo "❌ Instalação abortada para evitar conflito."
      exit 1
    fi
  else
    break
  fi
done

# Loop para porta válida
while true; do
  read -p "🔢 Porta para a aplicação (ex: 3001): " APP_PORT
  if lsof -i:$APP_PORT &>/dev/null; then
    echo "❌ Porta $APP_PORT já está em uso."
  else
    break
  fi
done

PROJECT_NAME=$(echo $DOMAIN | cut -d'.' -f1)
PROJECT_PATH="/var/www/$PROJECT_NAME"
LOG_FILE="/var/log/install-$PROJECT_NAME.log"

# Redirecionar saída para log
exec > >(tee -a $LOG_FILE) 2>&1

echo ""
echo "📦 Instalando dependências..."

apt update -y
apt install -y curl git nginx ufw unzip gnupg2 software-properties-common nano wget net-tools

# Node.js
if ! command -v node &> /dev/null; then
  echo "🧩 Instalando Node.js..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt install -y nodejs
fi

# PM2
if ! command -v pm2 &> /dev/null; then
  echo "🧩 Instalando PM2..."
  npm install -g pm2
fi

# Certbot
if ! command -v certbot &> /dev/null; then
  echo "🔒 Instalando Certbot..."
  apt install -y certbot python3-certbot-nginx
fi

echo ""
echo "📁 Clonando repositório para $PROJECT_PATH..."
git clone $GIT_REPO $PROJECT_PATH || { echo "❌ Falha ao clonar repositório"; exit 1; }
cd $PROJECT_PATH

# Criar arquivo .env
echo "PORT=$APP_PORT" > .env

# Instalar dependências com tentativa
until npm install; do
  echo "❌ Falha ao instalar dependências."
  read -p "Deseja tentar novamente? (s/n): " TENTAR
  [[ "$TENTAR" == "s" || "$TENTAR" == "S" ]] || exit 1
done

# Build com tentativa
until npm run build; do
  echo "❌ Falha ao buildar o projeto."
  read -p "Deseja tentar novamente? (s/n): " TENTAR2
  [[ "$TENTAR2" == "s" || "$TENTAR2" == "S" ]] || exit 1
done

# Rodar com PM2
echo "🚀 Iniciando com PM2..."
pm2 start npm --name "$PROJECT_NAME" -- start
pm2 save
pm2 startup | bash

ufw allow "$APP_PORT"
ufw allow 'Nginx Full'

# Criar configuração Nginx
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
echo "🔧 Criando configuração Nginx..."
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
echo "🔒 Instalando certificado SSL com Certbot..."
certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# Teste final do domínio
echo ""
echo "🔎 Verificando se o domínio responde com HTTPS..."
sleep 3
if curl -s --head "https://$DOMAIN" | grep "200 OK" > /dev/null; then
  SSL_STATUS="✅ Domínio $DOMAIN está acessível com HTTPS!"
else
  SSL_STATUS="⚠️ Domínio $DOMAIN ainda não respondeu com status 200. Pode ser propagação ou houve falha."
fi

# RESUMO FINAL
echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║            ✅ INSTALAÇÃO CONCLUÍDA              ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "📌 Projeto:     $PROJECT_NAME"
echo "🌐 Domínio:     https://$DOMAIN"
echo "🔢 Porta:       $APP_PORT"
echo "📂 Caminho:     $PROJECT_PATH"
echo "🧾 Log:         $LOG_FILE"
echo ""
echo "$SSL_STATUS"
echo ""
