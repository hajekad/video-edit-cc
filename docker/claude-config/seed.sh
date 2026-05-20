#!/usr/bin/env bash
# Seeds /root/.claude from /opt/claude-config on every container start.
# Idempotent — always upserts the latest baked config so edits to
# host-side docker/claude-config/ propagate on container restart.
# The named /root/.claude volume retains session/history/credentials.

set -e

SRC=/opt/claude-config
DST=/root/.claude

mkdir -p "$DST" "$DST/hooks" "$DST/commands"

install -m 0644 "$SRC/settings.json" "$DST/settings.json"
install -m 0755 "$SRC/statusline.sh" "$DST/statusline.sh"
install -m 0755 "$SRC/scaffold-project.sh" "$DST/scaffold-project.sh"

# Install every hook from the baked dir; chmod +x.
for f in "$SRC/hooks"/*.sh; do
  [ -f "$f" ] || continue
  install -m 0755 "$f" "$DST/hooks/$(basename "$f")"
done

# Install every slash command (markdown) from the baked dir.
for f in "$SRC/commands"/*.md; do
  [ -f "$f" ] || continue
  install -m 0644 "$f" "$DST/commands/$(basename "$f")"
done

exec "$@"
