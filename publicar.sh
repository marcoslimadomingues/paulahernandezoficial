#!/bin/bash
# Sobe arquivos por FTP, confere no ar e notifica o IndexNow.
# Uso: bash publicar.sh index.html slug/index.html ...
set -e

HOST="servidor.idc2br.com"
USUARIO="PREENCHER"
SENHA="PREENCHER"
DOMINIO="paulahernandezoficial.com.br"
CHAVE="137f9f9d492df6f9458e0da3c287f2559c864636b1c3854ea3989a4ae8df6908"

if [ "$USUARIO" = "PREENCHER" ]; then
  echo "Preencha USUARIO e SENHA no topo deste arquivo antes de usar."
  exit 1
fi

URLS=""
for f in "$@"; do
  curl -T "$f" "ftp://$HOST:21/public_html/$f" --user "$USUARIO:$SENHA" --ftp-create-dirs -sS
  echo "enviado: $f"
  URL="https://$DOMINIO/$(dirname "$f" | sed 's|^\.$||')"
  URL="${URL%/.}"
  [ "$(basename "$f")" = "index.html" ] && URL="${URL%/}/"
  URLS="$URLS\"$URL\","
done

URLS="[${URLS%,}]"
curl -s -X POST "https://api.indexnow.org/indexnow" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d "{\"host\":\"$DOMINIO\",\"key\":\"$CHAVE\",\"keyLocation\":\"https://$DOMINIO/$CHAVE.txt\",\"urlList\":$URLS}" \
  -w "\nIndexNow: HTTP %{http_code}\n"

echo
echo "PENDENTE: pedir reindexação no Google Search Console (ele não usa IndexNow)."
