#!/usr/bin/env bash
set -euo pipefail
cd /mnt/d/projects/26-0523_maps

git add -A
git status --short | head -60

cat > /tmp/femaps_commit_msg.txt <<'EOF'
Initial commit: docs, scripts, docker; exclude map rasters.
EOF

git commit -F /tmp/femaps_commit_msg.txt
git status -sb
git log -1 --oneline
git remote -v
