#!/usr/bin/env bash
# Установка @bytebase/dbhub локально в .cursor/dbhub
# Использование: ./scripts/setup-dbhub.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DBHUB_DIR="$PROJECT_ROOT/.cursor/dbhub"

echo "=== Установка DBHub (femaps) ==="
echo "Проект: $PROJECT_ROOT"
echo "DBHub:  $DBHUB_DIR"
echo ""

mkdir -p "$DBHUB_DIR"

if [[ ! -f "$DBHUB_DIR/package.json" ]]; then
  echo "Нет package.json — создайте .cursor/dbhub/package.json и повторите."
  exit 1
fi

cd "$DBHUB_DIR"
echo "npm install @bytebase/dbhub..."
npm install --silent

# ssh-config@5 — только ESM; dbhub грузит через CJS → SyntaxError. Pin 4.1.6 (как в femsq).
if ! grep -q '"ssh-config": "4.1.6"' "$DBHUB_DIR/package.json" 2>/dev/null; then
  node -e "
    const fs = require('fs');
    const p = process.argv[1];
    const j = JSON.parse(fs.readFileSync(p, 'utf8'));
    j.overrides = j.overrides || {};
    j.overrides['ssh-config'] = '4.1.6';
    j.overrides.mariadb = j.overrides.mariadb || '3.4.0';
    fs.writeFileSync(p, JSON.stringify(j, null, 2) + '\n');
  " "$DBHUB_DIR/package.json"
  npm install --silent
fi

IDX="$DBHUB_DIR/node_modules/@bytebase/dbhub/dist/index.js"
if [[ -f "$IDX" ]]; then
  echo "✓ DBHub установлен: $IDX"
else
  echo "✗ Не найден $IDX"
  exit 1
fi

echo ""
echo "Далее: скопируйте нужный шаблон в .cursor/mcp.json и перезагрузите MCP в Cursor."
echo "  maps_db local:  .cursor/mcp.maps-db.local.json.example"
echo "  maps_db remote: .cursor/mcp.maps-db.remote.json.example"
echo "  FishEye WG:     .cursor/mcp.fisheye.remote.json.example  (подставьте пароль)"
echo "  ./scripts/setup-cursor-mcp.sh   — выбрать шаблон по hostname / флагу"
