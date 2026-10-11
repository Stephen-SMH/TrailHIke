#!/usr/bin/env bash
# Everything that can be checked on this machine, against the local dev server.
set -euo pipefail
cd "$(dirname "$0")/.."
KEY="$(grep -o 'sb_publishable[^"]*' env/dev.json)"
ANON="$(npx --yes supabase status -o env | grep '^ANON_KEY' | cut -d'"' -f2)"
URL="$(grep -o 'http://[^"]*' env/dev.json)"
echo "== analyze"; flutter analyze
echo "== unit + widget tests"; flutter test
echo "== database rules (RLS)"; API_URL="$URL" ANON_KEY="$ANON" node supabase/tests/rls.test.mjs
echo "== real backend client"; SUPABASE_URL="$URL" SUPABASE_KEY="$KEY" flutter test test/supabase_integration_test.dart
