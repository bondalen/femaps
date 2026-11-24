# DBHub (MCP) в femaps

Локальный MCP-сервер [@bytebase/dbhub](https://www.npmjs.com/package/@bytebase/dbhub) для SQL из Cursor.

## Установка

```bash
./scripts/setup-dbhub.sh
./scripts/setup-cursor-mcp.sh          # maps_db: local на nb-win, remote (WG) иначе
./scripts/setup-cursor-mcp.sh fisheye  # MS SQL FishEye_prod_noM6 @ 10.7.0.3
```

Перезагрузите MCP в Cursor (Settings → MCP) или перезапустите окно.

## Шаблоны DSN

| Файл | Назначение |
|------|------------|
| `mcp.maps-db.local.json.example` | PostGIS `maps_db` на `localhost:5434` |
| `mcp.maps-db.remote.json.example` | PostGIS `maps_db` на `10.7.0.3:5434` (WireGuard) |
| `mcp.fisheye.remote.json.example` | MS SQL `FishEye_prod_noM6` на `10.7.0.3:1433` |

Рабочий `.cursor/mcp.json` в `.gitignore` (секреты). Один активный DSN за раз: для смены базы снова запустите `setup-cursor-mcp.sh` с нужной целью.

Для `fisheye` пароль берётся из `FEMAPS_FISHEYE_PASSWORD` или `~/.femsq/database.properties` (`password=`).

## Замечания

- Пакет лежит в `.cursor/dbhub/` (не корневой npm проекта).
- На remote-станции нужен WireGuard (`vps-vpn` → `10.7.0.3`).
- Таймаут длинных запросов у DBHub ограничен (~15 с) — тяжёлые скрипты лучше через клиент БД.
