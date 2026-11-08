#!/usr/bin/env bash
# deploy the agent page to Supabase Storage and the schema to Postgres
set -euo pipefail
cd "$(dirname "$0")"

DB=$(cat ~/.config/supabase-lumavir.url)
PRJ=$(printf '%s' "$DB" | sed -n 's|.*postgres\.\([a-z0-9]*\):.*|\1|p')
KEY=$(grep -oE 'eyJ[A-Za-z0-9._-]{40,}' ~/.config/aristral/seodb.env | while read -r k; do
        python3 - "$k" <<'PY'
import base64, json, sys
t = sys.argv[1].split('.')[1]; t += '=' * (-len(t) % 4)
r = json.loads(base64.urlsafe_b64decode(t)).get('role')
if r == 'service_role': print(sys.argv[1])
PY
      done | head -1)

[ -n "$PRJ" ] && [ -n "$KEY" ] || { echo "missing project ref or service key"; exit 1; }
BASE="https://$PRJ.supabase.co"
API=(-H "apikey: $KEY" -H "Authorization: Bearer $KEY")

echo "1/4 schema"
psql "$DB" -v ON_ERROR_STOP=1 -q -f sql/schema.sql

echo "2/4 bucket"
curl -sS -X POST "$BASE/storage/v1/bucket" "${API[@]}" -H 'Content-Type: application/json' \
  -d '{"id":"agent","name":"agent","public":true}' -o /dev/null -w '  bucket %{http_code}\n' || true

echo "3/4 upload"
for f in index.html sw.js manifest.json; do
  ct=text/html; [[ $f == *.js ]] && ct=application/javascript; [[ $f == *.json ]] && ct=application/json
  sed -e "s|__PRJ__|$PRJ|g" -e "s|__KEY__|$KEY|g" "$f" > ".up-$f"
  curl -sS -X POST "$BASE/storage/v1/object/agent/$f" "${API[@]}" \
    -H "Content-Type: $ct" -H "Cache-Control: no-store" -H 'x-upsert: true' \
    --data-binary "@.up-$f" -o /dev/null -w "  $f %{http_code}\n"
  rm -f ".up-$f"
done

echo "4/4 verify"
URL="$BASE/storage/v1/object/public/agent/index.html"
curl -sS -o /dev/null -D - "$URL" | tr -d '\r' | grep -iE '^HTTP/|^content-type' | sed 's/^/  /'
echo
echo "target link:  $URL"
echo "operator:     ${URL}?r=<RUN>&op=1"
