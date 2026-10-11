#!/usr/bin/env bash
# Start the local dev backend (Docker + Supabase CLI). Needs Docker running.
# Ports are 5442x so it can sit beside other local Supabase projects.
set -euo pipefail
cd "$(dirname "$0")/.."
npx --yes supabase start -x studio,storage-api,imgproxy,vector,logflare,edge-runtime,mailpit,supavisor
echo
echo "Dev server ready. Run the app against it:"
echo "  flutter run -d chrome --dart-define-from-file=env/dev.json"
