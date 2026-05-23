#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_DIR/ssl"

mkdir -p "$SSL_DIR"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$SSL_DIR/short-link.key" \
  -out "$SSL_DIR/short-link.crt" \
  -subj "/C=BR/ST=SP/O=URLShortener/CN=localhost"

echo "[OK] Self-signed SSL certificates generated in $SSL_DIR/"
echo "     证书文件 (cert):  $SSL_DIR/short-link.crt"
echo "     密钥文件 (key):   $SSL_DIR/short-link.key"
echo ""
echo "警告: 这些证书仅用于本地开发环境。生产环境应使用受信任的 CA 颁发的证书。"