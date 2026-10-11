#!/usr/bin/env bash
# Build the web app for one environment.
#   scripts/build_web.sh dev|staging|prod
# Output: build/web  (static files; upload to any host)
set -euo pipefail
ENV="${1:?usage: build_web.sh dev|staging|prod}"
FILE="env/$ENV.json"
[ -f "$FILE" ] || { echo "missing $FILE (copy env/$ENV.example.json)"; exit 1; }
cd "$(dirname "$0")/.."
flutter build web --release --dart-define-from-file="$FILE" --pwa-strategy=none
# Host config (Netlify format; harmless elsewhere).
echo '/*  /index.html  200' > build/web/_redirects
{
  echo '/*'
  echo '  Permissions-Policy: geolocation=(self)'
  echo '  X-Content-Type-Options: nosniff'
  echo '  Referrer-Policy: no-referrer'
  # Staging is for testers only: keep it out of search engines.
  [ "$ENV" = "prod" ] || echo '  X-Robots-Tag: noindex, nofollow'
  echo '/flutter_service_worker.js'
  echo '  Cache-Control: no-cache'
  echo '/index.html'
  echo '  Cache-Control: no-cache'
} > build/web/_headers
echo "Built build/web for $ENV"
