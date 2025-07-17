# 🚀 Instalador Automático para Projetos V0 / Next.js

Este script instala automaticamente um projeto gerado pelo [V0.dev](https://v0.dev) ou qualquer app Next.js em uma VPS com Ubuntu.

## ✅ O que ele faz

- Instala Node.js, PM2, Nginx e Certbot
- Clona seu projeto do Git
- Pergunta a porta e o domínio
- Instala as dependências
- Faz o build do projeto
- Cria proxy com Nginx
- Instala certificado SSL gratuito com HTTPS

## ⚙️ Como usar

Na sua VPS, execute:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/rafael-mcd-filho/instalador-v0/main/setup.sh)
