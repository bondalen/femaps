#!/usr/bin/env bash
# Создаёт .cursor/mcp.json из шаблона.
# Использование:
#   ./scripts/setup-cursor-mcp.sh                 # maps_db: local на nb-win, remote (WG) иначе
#   ./scripts/setup-cursor-mcp.sh maps-db-local
#   ./scripts/setup-cursor-mcp.sh maps-db-remote
#   ./scripts/setup-cursor-mcp.sh fisheye         # MS SQL FishEye_prod_noM6 @ 10.7.0.3
#
# Пароль FishEye: FEMAPS_FISHEYE_PASSWORD или ~/.femsq/database.properties (password=).
# .cursor/mcp.json в .gitignore — после pull запускайте скрипт на своей машине.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MCP_FILE="$PROJECT_ROOT/.cursor/mcp.json"
HOSTNAME="$(hostname)"
TARGET="${1:-}"

is_remote_dev_host() {
  [[ "$HOSTNAME" =~ [Ff]edora ]] \
    || [[ "$HOSTNAME" == "alex-fedora" ]] \
    || [[ "$HOSTNAME" == "asus-kubuntu" ]] \
    || [[ "$HOSTNAME" == "localhost.localdomain" ]]
}

pick_default_target() {
  case "$HOSTNAME" in
    nb-win) echo "maps-db-local" ;;
    *)
      if is_remote_dev_host; then
        echo "maps-db-remote"
      else
        echo ""
      fi
      ;;
  esac
}

if [[ -z "$TARGET" ]]; then
  TARGET="$(pick_default_target)"
fi

case "$TARGET" in
  maps-db-local)  TEMPLATE="$PROJECT_ROOT/.cursor/mcp.maps-db.local.json.example" ;;
  maps-db-remote) TEMPLATE="$PROJECT_ROOT/.cursor/mcp.maps-db.remote.json.example" ;;
  fisheye)        TEMPLATE="$PROJECT_ROOT/.cursor/mcp.fisheye.remote.json.example" ;;
  *)
    echo "Неизвестная цель / hostname: target='${TARGET:-}' hostname='$HOSTNAME'"
    echo "Укажите явно: maps-db-local | maps-db-remote | fisheye"
    exit 1
    ;;
esac

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Нет шаблона: $TEMPLATE"
  exit 1
fi

if [[ ! -f "$PROJECT_ROOT/.cursor/dbhub/node_modules/@bytebase/dbhub/dist/index.js" ]]; then
  echo "DBHub не установлен — запуск setup-dbhub.sh..."
  "$SCRIPT_DIR/setup-dbhub.sh"
fi

mkdir -p "$(dirname "$MCP_FILE")"
cp "$TEMPLATE" "$MCP_FILE"

if [[ "$TARGET" == "fisheye" ]]; then
  PASS="${FEMAPS_FISHEYE_PASSWORD:-}"
  if [[ -z "$PASS" && -f "$HOME/.femsq/database.properties" ]]; then
    PASS="$(awk -F= '/^password=/{print substr($0,index($0,"=")+1); exit}' "$HOME/.femsq/database.properties")"
  fi
  if [[ -z "$PASS" || "$PASS" == "CHANGE_ME" ]]; then
    echo "⚠ Задайте пароль FishEye: FEMAPS_FISHEYE_PASSWORD=... или password= в ~/.femsq/database.properties"
    echo "  Сейчас в DSN остался плейсхолдер CHANGE_ME"
  else
    # Подставить пароль в DSN (только локальный gitignored mcp.json)
    node -e "
      const fs = require('fs');
      const p = process.argv[1];
      const pass = process.argv[2];
      const j = JSON.parse(fs.readFileSync(p, 'utf8'));
      j.mcpServers.dbhub.env.DSN = j.mcpServers.dbhub.env.DSN.replace('CHANGE_ME', pass);
      fs.writeFileSync(p, JSON.stringify(j, null, 2) + '\n');
    " "$MCP_FILE" "$PASS"
  fi
fi

echo "✓ Создан $MCP_FILE"
echo "  hostname: $HOSTNAME"
echo "  target:   $TARGET"
echo "  шаблон:   $(basename "$TEMPLATE")"
echo ""
echo "Перезапустите Cursor или перезагрузите MCP (Settings → MCP)."
