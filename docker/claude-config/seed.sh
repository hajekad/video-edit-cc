#!/usr/bin/env bash
# Seeds /root/.claude from /opt/claude-config on every container start.
#
# CRITICAL — uses SYMLINKS for hooks/ and commands/, not copies. Reason:
# docker cp during a live session updates /opt/claude-config/, but if we
# install-copy at startup, the runtime path /root/.claude/ stays stale
# and the agent runs against pre-session versions of hooks/commands.
# Smoke test #2 hit exactly this: every harness hot-patch landed at /opt
# but never reached the agent because /root/.claude was copied once at
# container start. Symlinks make /opt → /root reflect instantly.
#
# The named /root/.claude volume retains session/history/credentials.
# settings.json / statusline.sh / scaffold-project.sh remain copies
# because the CLI may rewrite them.

set -e

SRC=/opt/claude-config
DST=/root/.claude

mkdir -p "$DST"

# Files that must remain copies (CLI may rewrite them).
install -m 0644 "$SRC/settings.json" "$DST/settings.json"
install -m 0755 "$SRC/statusline.sh" "$DST/statusline.sh"
install -m 0755 "$SRC/scaffold-project.sh" "$DST/scaffold-project.sh"

# Directories that must mirror /opt live — replace any existing copy
# with a fresh symlink on every container start.
for d in hooks commands; do
  if [ -L "$DST/$d" ]; then
    rm -f "$DST/$d"
  elif [ -d "$DST/$d" ]; then
    rm -rf "$DST/$d"
  fi
  ln -s "$SRC/$d" "$DST/$d"
done

exec "$@"
